import Foundation

/// Hermes has a directory plugin API. This template preserves the original
/// Vibe Island lifecycle sequence and only substitutes the local bridge path.
public enum HermesPluginTemplate {
    public static let marker = "MY_VIBE_ISLAND_MANAGED_HERMES_PLUGIN v1"

    public static let manifest = """
    name: vibe-island
    version: "1.0.0"
    description: "Vibe Island notch panel — real-time session status in macOS Dynamic Island"
    author: "vibeisland.app"
    provides_hooks:
      - on_session_start
      - on_session_end
      - on_session_finalize
      - pre_llm_call
      - post_llm_call
      - pre_tool_call
      - post_tool_call
    """ + "\n"

    public static let module = """
    # MY_VIBE_ISLAND_MANAGED_HERMES_PLUGIN v1
    # Derived from the original Vibe Island Hermes plugin lifecycle contract.
    import json
    import os
    import subprocess
    import threading
    import uuid

    _BRIDGE = os.path.expanduser("~/.my-vibe-island/bin/my-vibe-island-bridge")

    def _send(event_name, reliable=False, **kwargs):
        if not os.path.isfile(_BRIDGE):
            return False
        payload = {"hook_event_name": event_name}
        payload.update(kwargs)
        command = [_BRIDGE, "--source", "hermes"]
        if reliable:
            command.append("--wait-for-ack")
        try:
            return subprocess.run(
                command,
                input=json.dumps(payload).encode("utf-8"),
                capture_output=True,
                timeout=2,
            ).returncode == 0
        except Exception:
            return False

    def register(ctx):
        turns = {}
        lock = threading.Lock()

        def text(value):
            return str(value) if value else ""

        def key(session_id, turn_id="", task_id=""):
            return (text(session_id), text(turn_id) or text(task_id))

        def ensure_turn(session_id, turn_id="", task_id=""):
            identity = key(session_id, turn_id, task_id)
            if not identity[0]:
                return identity, None
            with lock:
                state = turns.get(identity)
                if state is None:
                    correlation = identity[1] or uuid.uuid4().hex
                    state = {
                        "cwd": os.getcwd(),
                        "event_id": "hermes:%s:%s:terminal" % (identity[0], correlation),
                    }
                    turns[identity] = state
            return identity, state

        def take_turn(session_id, turn_id="", task_id=""):
            identity = key(session_id, turn_id, task_id)
            with lock:
                return identity, turns.pop(identity, None)

        def finish_turn(identity):
            with lock:
                turns.pop(identity, None)

        def context(session_id, turn_id="", task_id="", cwd=None):
            payload = {"session_id": text(session_id), "cwd": cwd or os.getcwd()}
            if turn_id:
                payload["turn_id"] = text(turn_id)
            if task_id:
                payload["task_id"] = text(task_id)
            return payload

        def on_session_start(session_id="", **kwargs):
            if text(session_id):
                _send("SessionStart", session_id=text(session_id), cwd=os.getcwd())

        def before_llm(session_id="", user_message="", turn_id="", task_id="", **kwargs):
            identity, state = ensure_turn(session_id, turn_id, task_id)
            if state is None:
                return
            state["cwd"] = os.getcwd()
            _send("UserPromptSubmit", prompt=text(user_message)[:200],
                  **context(identity[0], turn_id, task_id, state["cwd"]))

        def after_llm(session_id="", assistant_response="", turn_id="", task_id="", **kwargs):
            identity, state = ensure_turn(session_id, turn_id, task_id)
            if state is None or not assistant_response:
                return
            payload = context(identity[0], turn_id, task_id, state["cwd"])
            payload["event_id"] = state["event_id"]
            payload["last_assistant_message"] = text(assistant_response)[:500]
            state["terminal"] = ("Stop", payload)
            if _send("Stop", reliable=True, **payload):
                finish_turn(identity)

        def on_session_end(session_id="", completed=False, interrupted=False, turn_id="", task_id="", **kwargs):
            identity, state = take_turn(session_id, turn_id, task_id)
            if state is None:
                return
            terminal = state.get("terminal")
            if terminal:
                event_name, payload = terminal
                _send(event_name, reliable=True, **payload)
                return
            payload = context(identity[0], turn_id, task_id, state["cwd"])
            payload["event_id"] = state["event_id"]
            payload["completed"] = bool(completed)
            payload["interrupted"] = bool(interrupted)
            event_name = "Stop" if completed else "StopFailure"
            if not completed:
                payload["last_assistant_message"] = "Turn aborted" if interrupted else "Error: Hermes turn failed"
            _send(event_name, reliable=True, **payload)

        def on_session_finalize(session_id="", reason="", **kwargs):
            session = text(session_id)
            if not session:
                return
            with lock:
                for identity in [item for item in turns if item[0] == session]:
                    turns.pop(identity, None)
            _send("SessionEnd", reliable=True, session_id=session, cwd=os.getcwd(), message=text(reason))

        def before_tool(tool_name="", session_id="", turn_id="", task_id="", **kwargs):
            if text(session_id):
                _send("PreToolUse", tool_name=tool_name or "tool", **context(session_id, turn_id, task_id))

        def after_tool(tool_name="", session_id="", turn_id="", task_id="", **kwargs):
            if text(session_id):
                _send("PostToolUse", tool_name=tool_name or "tool", **context(session_id, turn_id, task_id))

        ctx.register_hook("on_session_start", on_session_start)
        ctx.register_hook("pre_llm_call", before_llm)
        ctx.register_hook("post_llm_call", after_llm)
        ctx.register_hook("on_session_end", on_session_end)
        ctx.register_hook("on_session_finalize", on_session_finalize)
        ctx.register_hook("pre_tool_call", before_tool)
        ctx.register_hook("post_tool_call", after_tool)
    """ + "\n"
}
