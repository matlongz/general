# tailscale-fe80-guard

Workaround for a Tailscale direct-path failure between two nodes on the same
LAN. Install on any **server** node in the tailnet (tars is the reference
instance); nothing is needed on clients.

## Symptom

After a peer laptop sleeps/wakes (or moves from a remote network back onto the
LAN), all traffic to the server over the tailnet times out, while:

- `tailscale status` still claims `active; direct [fe80::…]:41641` — note the
  IPv6 **link-local** endpoint; the healthy direct path looks like
  `direct <lan-ipv4>:41641`
- `tailscale ping <server>` pongs normally (disco probes traverse the path)
- the client's peer counters show `tx` growing but `rx 0` — WireGuard data is
  blackholed one-way on the same UDP 5-tuple the disco probes pass through

`tailscale down/up`, client app restarts, and `tailscale debug rebind`/`restun`
do not reliably clear it: magicsock prefers IPv6 endpoints at similar latency
and keeps re-validating the fe80 path because disco works. There is no
official knob to disable link-local endpoints — open FR
[tailscale/tailscale#13705](https://github.com/tailscale/tailscale/issues/13705)
(both ends on 1.98.8 when diagnosed, 2026-07).

## Fix

A dedicated nftables table that drops UDP on the server's tailscaled listen
port (default `41641`) when the other side is a link-local (`fe80::/10`)
address. Path discovery can then never validate an fe80 endpoint pair, so
peers settle on the direct IPv4 LAN path, which is unaffected by the bug.
Matching is pinned to the **server's own** socket (input `dport` / output
`sport`), so it holds regardless of which port a client uses.

Deliberately **not** wired into `/etc/nftables.conf` + `nftables.service`:
that stock config starts with `flush ruleset`, which would wipe the
iptables-nft rules Docker/KIND manage at runtime. The isolated table + oneshot
unit coexist with container networking and roll back without touching it.

## Install (Debian; run as root)

```sh
cd ~/.config/dotfiles/server/tailscale-fe80-guard
install -m 644 -o root -g root tailscale-fe80-guard.nft /etc/nftables-tailscale-fe80-guard.nft
install -m 644 -o root -g root tailscale-fe80-guard.service /etc/systemd/system/tailscale-fe80-guard.service
systemctl daemon-reload
systemctl enable --now tailscale-fe80-guard.service
```

Verify from a client on the same LAN: `tailscale status` should show
`direct <lan-ipv4>:41641` for this server, and SSH/HTTPS over the tailnet IP
should work — including after a client sleep/wake cycle.

## Rollback

```sh
systemctl disable --now tailscale-fe80-guard.service
```

`ExecStop` destroys only its own table (`nft destroy table inet
tailscale_fe80_guard`) — an exact inverse; no other firewall state is touched
at any point.

## Reuse on another server

Works as-is if the new server's tailscaled listens on the default UDP `41641`
(check: `ss -lun | grep 41641`). If it uses a custom `--port`, change both
port matches in the `.nft` file. Requires nftables ≥ 1.0.8 (`destroy table`);
Debian 13 ships 1.1.3. Trade-off to be aware of: the guard disables
link-local direct paths between this server and **all** tailnet peers on its
LAN — they fall back to IPv4 LAN direct (same speed), remote peers are
unaffected (public direct / DERP paths don't use fe80).
