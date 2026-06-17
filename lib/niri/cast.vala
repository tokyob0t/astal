
namespace AstalNiri {

public class Cast : Object {
    public signal void stopped();

    // Stream ID of the screencast that uniquely identifies it.
    public uint64 stream_id { get; private set; }
    // Session ID of the screencast.
    public uint64 session_id { get; private set; }
    // Process ID of the screencast consumer, if known.
    public int? pid { get; private set; }
    // PipeWire node ID of the screencast stream.
    public int? pw_node_id { get; private set; }

    // Kind of this screencast. Pipewire | WlrScreencopy
    public CastKind kind { get; private set; }

    public bool is_active { get; internal set; }
    public bool is_dynamic_target { get; private set; }

    private string? active_output_name;
    private int64? active_window_id;

    // Replaces CastTarget
    public unowned Window? window { get {
        return Niri.get_default().get_window(active_window_id);
    }}

    public unowned Output? output { get {
        return Niri.get_default().get_output(active_output_name);
    }}

    internal Cast.from_json(Json.Object object) {
        sync(object);
    }

    internal void sync(Json.Object object) {
        stream_id = (uint64) object.get_int_member("stream_id");
        session_id = (uint64) object.get_int_member("session_id");
        is_active = object.get_boolean_member("is_active");
        is_dynamic_target = object.get_boolean_member("is_dynamic_target");

        if (object.has_member("pid") && !object.get_null_member("pid")) {
            pid = (int32) object.get_int_member("pid");
        } else {
            pid = null;
        }

        if (object.has_member("pw_node_id") && !object.get_null_member("pw_node_id")) {
            pw_node_id = (int32) object.get_int_member("pw_node_id");
        } else {
            pw_node_id = null;
        }

        var k = object.get_string_member("kind");

        if (k == "PipeWire") {
            kind = CastKind.PipeWire;
        } else if (k == "WlrScreencopy") {
            kind = CastKind.WlrScreencopy;
        } else {
            warning("Unknown CastKind");
        }

        var target = object.get_object_member("target");

        if (target.has_member("Nothing")) {
            active_output_name = null;
            active_window_id = null;
        } else if (target.has_member("Output")) {
            active_window_id = null;

            active_output_name = target
                .get_object_member("Output")
                .get_string_member("name");

        } else if (target.has_member("Window")) {
            active_output_name = null;

            active_window_id = target.get_object_member("Window")
                  .get_int_member("id");
        }

    }

    public bool stop() {
        return msg.stop_cast((int)stream_id);
    }
}
}
