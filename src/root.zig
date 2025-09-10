const std = @import("std");
const builtin = @import("builtin");
const OS = builtin.os.tag;

pub const KEY_COUNT = 256; // Standardize on 256 keys

pub const KeyboardError = error{
    GetKeyboardStateFailed,
    NoInputDevice,
    OutOfMemory,
};

const win32 = if (OS == .windows) @cImport({
    @cInclude("windows.h");
}) else struct {};

const macos = @cImport({
    @cInclude("ApplicationServices/ApplicationServices.h");
});

const libinput = if (OS == .linux) @cImport({
    @cInclude("libinput.h");
    @cInclude("libudev.h");
    @cInclude("linux/input.h");
}) else struct {};

var state: [KEY_COUNT]bool = undefined;
// === keyboard state ===
pub fn update() KeyboardError!void {
    if (OS == .windows) {
        var key_bytes: [KEY_COUNT]u8 = undefined;
        if (win32.GetKeyboardState(&key_bytes) == 0) {
            return KeyboardError.GetKeyboardStateFailed;
        }
        for (key_bytes, 0..) |byte, i| {
            state[i] = (byte & 0x80) != 0; // High bit set means pressed
        }
    } else if (OS == .macos) {
        // for all 128 keys loop over cgeventsource to get key state
        for (0..128) |i| {
            const keycode: macos.CGKeyCode = @intCast(i);
            state[i] = macos.CGEventSourceKeyState(macos.kCGEventSourceStateHIDSystemState, keycode);
        }
    } else if (OS == .linux) {
        // Initialize libinput with udev
        const udev = libinput.udev_new() orelse return KeyboardError.NoInputDevice;
        defer libinput.udev_unref(udev);

        const li = libinput.udev_create_context(udev, null, null) orelse return KeyboardError.NoInputDevice;
        defer libinput.libinput_unref(li);

        // Assign a seat (usually "seat0" for default)
        if (libinput.udev_assign_seat(li, "seat0") != 0) {
            return KeyboardError.NoInputDevice;
        }

        // Open the first keyboard device
        var device: ?*libinput.libinput_device = null;
        var iter = libinput.libinput_device_list(li);
        while (libinput.libinput_device_list_next(&iter)) |dev| {
            if (libinput.libinput_device_has_capability(dev, libinput.LIBINPUT_DEVICE_CAP_KEYBOARD) != 0) {
                device = dev;
                break;
            }
        }
        if (device == null) return KeyboardError.NoInputDevice;

        // Open the device file descriptor
        const path = libinput.libinput_device_get_syspath(device);
        const fd = std.os.open(path, std.os.O.RDONLY | std.os.O.NONBLOCK, 0) catch {
            return KeyboardError.NoInputDevice;
        };
        defer std.os.close(fd);

        // Poll events to update key states
        // var event: [1]libinput.input_event = undefined;
        while (libinput.libinput_dispatch(li) == 0) {
            const ev = libinput.libinput_get_event(li) orelse break;
            defer libinput.libinput_event_destroy(ev);

            if (libinput.libinput_event_get_type(ev) == libinput.LIBINPUT_EVENT_KEYBOARD_KEY) {
                const key_event = libinput.libinput_event_get_keyboard_event(ev);
                const keycode = libinput.libinput_event_keyboard_get_key(key_event);
                const key_state = libinput.libinput_event_keyboard_get_key_state(key_event);
                if (keycode < KEY_COUNT) {
                    state[keycode] = key_state == libinput.LIBINPUT_KEY_STATE_PRESSED;
                }
            }
        }
    } else {
        @compileError("Unsupported OS");
    }
    return;
}

// === key mapping ===
pub const Key = enum { A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, num_0, num_1, num_2, num_3, num_4, num_5, num_6, num_7, num_8, num_9, numPad_0, numPad_1, numPad_2, numPad_3, numPad_4, numPad_5, numPad_6, numPad_7, numPad_8, numPad_9, leftCtrl, rightCtrl, leftShift, rightShift, leftAlt, rightAlt, leftSuper, rightSuper, Tab, Escape, Space, Enter, Backspace, Up, Down, Left, Right, Home, End, PageUp, PageDown, Insert, Delete, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, period, comma, minus, equal, slash, backslash, semicolon, quote, leftBracket, rightBracket };
// const Key = enum { A, B, Escape };
pub fn getKeyName(key: Key) []const u8 {
    return switch (key) {
        .A => "A",
        .B => "B",
        .C => "C",
        .D => "D",
        .E => "E",
        .F => "F",
        .G => "G",
        .H => "H",
        .I => "I",
        .J => "J",
        .K => "K",
        .L => "L",
        .M => "M",
        .N => "N",
        .O => "O",
        .P => "P",
        .Q => "Q",
        .R => "R",
        .S => "S",
        .T => "T",
        .U => "U",
        .V => "V",
        .W => "W",
        .X => "X",
        .Y => "Y",
        .Z => "Z",
        .num_0 => "0",
        .num_1 => "1",
        .num_2 => "2",
        .num_3 => "3",
        .num_4 => "4",
        .num_5 => "5",
        .num_6 => "6",
        .num_7 => "7",
        .num_8 => "8",
        .num_9 => "9",
        .numPad_0 => "NumPad 0",
        .numPad_1 => "NumPad 1",
        .numPad_2 => "NumPad 2",
        .numPad_3 => "NumPad 3",
        .numPad_4 => "NumPad 4",
        .numPad_5 => "NumPad 5",
        .numPad_6 => "NumPad 6",
        .numPad_7 => "NumPad 7",
        .numPad_8 => "NumPad 8",
        .numPad_9 => "NumPad 9",
        .leftCtrl => "Left Ctrl",
        .rightCtrl => "Right Ctrl",
        .leftShift => "Left Shift",
        .rightShift => "Right Shift",
        .leftAlt => "Left Alt",
        .rightAlt => "Right Alt",
        .leftSuper => "Left Super (Windows/Command)",
        .rightSuper => "Right Super (Windows/Command)",
        .Tab => "Tab",
        .Escape => "Escape",
        .Space => "Space",
        .Enter => "Enter",
        .Backspace => "Backspace",
        .Up => "Up Arrow",
        .Down => "Down Arrow",
        .Left => "Left Arrow",
        .Right => "Right Arrow",
        .Home => "Home",
        .End => "End",
        .PageUp => "Page Up",
        .PageDown => "Page Down",
        .Insert => "Insert",
        .Delete => "Delete",
        .F1 => "F1",
        .F2 => "F2",
        .F3 => "F3",
        .F4 => "F4",
        .F5 => "F5",
        .F6 => "F6",
        .F7 => "F7",
        .F8 => "F8",
        .F9 => "F9",
        .F10 => "F10",
        .F11 => "F11",
        .F12 => "F12",
        .period => "Period",
        .comma => "Comma",
        .minus => "Minus",
        .equal => "Equal",
        .slash => "Slash",
        .backslash => "Backslash",
        .semicolon => "Semicolon",
        .quote => "Quote",
        .leftBracket => "Left Bracket",
        .rightBracket => "Right Bracket",
    };
}

pub fn getKeyboardState(key: Key) bool {
    return state[
        switch (OS) {
            .windows => switch (key) {
                .A => 0x41, // VK_A
                .Escape => 0x1B, // VK_ESCAPE
            },
            .macos => switch (key) {
                .A => 0x00,
                .B => 0x0B,
                .C => 0x08,
                .D => 0x02,
                .E => 0x0E,
                .F => 0x03,
                .G => 0x05,
                .H => 0x04,
                .I => 0x22,
                .J => 0x26,
                .K => 0x28,
                .L => 0x25,
                .M => 0x2E,
                .N => 0x2D,
                .O => 0x1F,
                .P => 0x23,
                .Q => 0x0C,
                .R => 0x0F,
                .S => 0x01,
                .T => 0x11,
                .U => 0x20,
                .V => 0x09,
                .W => 0x0D,
                .X => 0x07,
                .Y => 0x10,
                .Z => 0x06,
                .num_0 => 0x1D,
                .num_1 => 0x12,
                .num_2 => 0x13,
                .num_3 => 0x14,
                .num_4 => 0x15,
                .num_5 => 0x17,
                .num_6 => 0x16,
                .num_7 => 0x1A,
                .num_8 => 0x1C,
                .num_9 => 0x19,
                .numPad_0 => 0x52,
                .numPad_1 => 0x53,
                .numPad_2 => 0x54,
                .numPad_3 => 0x55,
                .numPad_4 => 0x56,
                .numPad_5 => 0x57,
                .numPad_6 => 0x58,
                .numPad_7 => 0x59,
                .numPad_8 => 0x5B,
                .numPad_9 => 0x5C,
                .leftCtrl => 0x3B,
                .rightCtrl => 0x3E,
                .leftShift => 0x38,
                .rightShift => 0x3C,
                .leftAlt => 0x3A,
                .rightAlt => 0x3D,
                .leftSuper => 0x37,
                .rightSuper => 0x36,
                .Tab => 0x30,
                .Escape => 0x35,
                .Space => 0x31,
                .Enter => 0x24,
                .Backspace => 0x33,
                .Up => 0x7E,
                .Down => 0x7D,
                .Left => 0x7B,
                .Right => 0x7C,
                .Home => 0x73,
                .End => 0x77,
                .PageUp => 0x74,
                .PageDown => 0x79,
                .Insert => 0x72,
                .Delete => 0x75,
                .F1 => 0x7A,
                .F2 => 0x78,
                .F3 => 0x63,
                .F4 => 0x76,
                .F5 => 0x60,
                .F6 => 0x61,
                .F7 => 0x62,
                .F8 => 0x64,
                .F9 => 0x65,
                .F10 => 0x6D,
                .F11 => 0x67,
                .F12 => 0x6F,
                .period => 0x2F,
                .comma => 0x2B,
                .minus => 0x1B,
                .equal => 0x18,
                .slash => 0x2C,
                .backslash => 0x2A,
                .semicolon => 0x29,
                .quote => 0x27,
                .leftBracket => 0x21,
                .rightBracket => 0x1E,
            },
            .linux => switch (key) {
                .A => 38, // KEY_A (Linux input event code)
                .Escape => 1, // KEY_ESC
            },
            else => unreachable,
        }
    ];
}
