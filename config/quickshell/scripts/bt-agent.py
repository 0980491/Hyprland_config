#!/usr/bin/env python3
# BlueZ pairing agent for the shell's Bluetooth page.
#
# Quickshell's Bluetooth module can pair, but it does not register an agent,
# and without one BlueZ can only do "just works" pairing: gamepads and most
# headsets are fine, but a keyboard that wants a code typed on it, or a phone
# that wants the six digits confirmed, fails with no explanation.
#
# This agent registers as the default one and:
#   · shows any passkey / PIN the other side needs as a notification
#     (type it on the keyboard, or check it matches on the phone)
#   · accepts numeric-comparison requests, but only while the adapter is
#     pairable — and the shell only turns that on while the Bluetooth page is
#     open or a pairing it started is running, so nobody nearby can pair
#     behind your back
#   · authorises services only for devices that are already paired
#   · answers legacy PIN requests with 0000, what nearly every old device uses
#
# Runs as the bt-agent.service user unit. Re-registers itself if bluetoothd
# restarts.
import subprocess

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS = "org.bluez"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_PATH = "/org/quickshell/btagent"
CAPABILITY = "KeyboardDisplay"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


def notify(title, body="", urgent=False):
    cmd = ["notify-send", "-a", "Bluetooth", "-i", "bluetooth"]
    if urgent:
        cmd += ["-u", "critical", "-t", "30000"]
    subprocess.Popen(cmd + [title, body])


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus

    def _props(self, path):
        obj = self.bus.get_object(BUS, path)
        return dbus.Interface(obj, "org.freedesktop.DBus.Properties")

    def _name(self, path):
        try:
            p = self._props(path)
            return str(p.Get("org.bluez.Device1", "Alias"))
        except dbus.DBusException:
            return str(path).rsplit("/", 1)[-1].replace("dev_", "").replace("_", ":")

    def _paired(self, path):
        try:
            return bool(self._props(path).Get("org.bluez.Device1", "Paired"))
        except dbus.DBusException:
            return False

    def _adapter_pairable(self, path):
        adapter = "/".join(str(path).split("/")[:4])  # /org/bluez/hci0
        try:
            return bool(self._props(adapter).Get("org.bluez.Adapter1", "Pairable"))
        except dbus.DBusException:
            return False

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        if self._paired(device):
            return
        raise Rejected("not paired")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        notify(f"Pairing {self._name(device)}", "Using PIN 0000")
        return "0000"

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        notify(f"Type {pincode} on {self._name(device)}", "then press Enter on it", urgent=True)

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        # We have no keyboard prompt to ask with; 0 is what "just works" uses.
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        if entered == 0:
            notify(f"Type {passkey:06d} on {self._name(device)}",
                   "then press Enter on it", urgent=True)

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        if not self._adapter_pairable(device):
            raise Rejected("adapter not pairable")
        notify(f"Pairing {self._name(device)}",
               f"Code {passkey:06d} — it should match what the device shows")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        if not self._adapter_pairable(device):
            raise Rejected("adapter not pairable")

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        pass


def register(bus):
    try:
        mgr = dbus.Interface(bus.get_object(BUS, "/org/bluez"), "org.bluez.AgentManager1")
        mgr.RegisterAgent(AGENT_PATH, CAPABILITY)
        mgr.RequestDefaultAgent(AGENT_PATH)
        print("agent registered", flush=True)
    except dbus.DBusException as e:
        # bluetoothd not up yet, or we are already registered
        print("register failed:", e.get_dbus_message(), flush=True)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    Agent(bus)

    def owner_changed(name, old, new):
        if name == BUS and new:
            register(bus)

    bus.add_signal_receiver(owner_changed, "NameOwnerChanged",
                            "org.freedesktop.DBus", arg0=BUS)
    register(bus)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
