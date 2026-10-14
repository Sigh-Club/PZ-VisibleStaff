# PZ VisibleStaff

Server-side fix for Project Zomboid **Build 42** dedicated servers where the
reported player count (server browser / Steam / in-game) silently excludes
staff and never refreshes for veteran characters.

No mods. No client changes. No server config edits. Two layers, both
verified in production:

1. **Staff roles are count-invisible by default.** The `admin` and
   `moderator` roles ship with the `HideFromSteamUserList` capability, and
   the login path only lists roles *without* it. Any server whose online
   players are staff reads low or zero. This is undocumented — the
   capability appears exactly once in the modding javadoc, as an enum name.
2. **Loaded characters never re-register.** The login-time
   `SteamGameServer.AddPlayer` call fires against a session that is not yet
   established and silently no-ops on relogs. An entry is only created on the
   character's first-ever login; after that the count can only decay. The
   same call works perfectly mid-session — proven by `setaccesslevel`
   moving the count live, in seconds, in either direction.

VisibleStaff fixes both by re-issuing the player-list entry shortly after
every login (30 s / 90 s / 180 s after full connect), for every role.

## Symptoms this fixes

- Server browser shows 0 (or a stale number) while people are in-world
- The count only ever includes freshly-created characters
- Staff and veteran regulars never appear; Indie Stone ticket
  "Active Users is not refreshing" closed unresolved describes the same
  behaviour

## The 30-second diagnosis

On the server console, with a staffer in-game:

```
setaccesslevel <Name> user
```

If the count jumps to include them, this is your server. (Restore with
`setaccesslevel <Name> admin`. Live, no restart.)

## Install (42.21.0)

```sh
./install.sh /path/to/ProjectZomboid
```

- Copies `42.21.0/visiblestaff/zombie/network/GameServer*.class` into
  `<server>/java/zombie/network/`.
- Works because the launcher's classpath lists the loose `java/.` directory
  **before** `java/projectzomboid.jar` — the JVM prefers the loose classes.
  Game files are never modified; delete the loose classes to uninstall.

Then restart the server. From the next login onward every role counts,
on every relog.

## How it works

`receivePlayerConnect` in `zombie.network.GameServer` gains a single
post-login re-assert: 60 s after full connect, if the player is still
connected, `SteamGameServer.AddPlayer` is issued once. By then the session
is mature and the call sticks — the exact call the game's own role-change
path (`SetAccessLevelCommand`) uses, which is what made the bug visible to
us in the first place. The re-assert is silent: one log line on success,
output only on error.

Each fire is logged (`VisibleStaff: ...` on stdout) so you can confirm it
is alive, and the full patch source is included
(`42.21.0/visiblestaff/src-GameServer.java` — decompiled with
[CFR](https://www.benf.org/other/cfr/) from the shipped 42.21.0 jar, then
edited; the diff against vanilla is the whole feature plus four
decompiler-artifact type fixes).

## Rebuilding for a new game version

1. Decompile `zombie/network/GameServer.class` from the **new** game jar
   with CFR.
2. Re-apply the VisibleStaff diff (it is small and annotated
   `SighNet VisibleStaff` / `VisibleStaff:`).
3. Compile against that same jar:
   `javac -cp projectzomboid.jar -d out src.../GameServer.java`
4. Ship the resulting `GameServer*.class` in a new version folder.

Game updates change signatures; always re-derive from the new jar rather
than reusing old classes.

## Verified

- Build 42.20.4 and 42.21.0, Linux dedicated servers (containerised), 8 GB
  ZGC heap
- User / admin / moderator roles; first login, relog, relay and direct
  connections; no duplicate entries observed in the A2S player payload
- Live proof: the counter tracks a mid-session `setaccesslevel` role flip
  within seconds, in both directions

## Known limits

- The native player-list implementation is closed source; the
  young-session no-op is characterised behaviourally, not from source.
- If TIS changes the login path in a future build, the patch must be
  re-derived (see above) — check the `VisibleStaff:` log lines after every
  game update.
- The capability rows in `Server<name>.db` are re-seeded by the server at
  boot: do **not** try to fix this by editing the database, it will not
  survive.

## Credits

- Decompilation: [CFR](https://www.benf.org/other/cfr/) and the
  [PZDecompiled](https://github.com/piromasta/PZDecompiled) reference tree
- The class-override delivery pattern as used by
  [apocalipsebr-zomboid-patches](https://github.com/rbm4/apocalipsebr-zomboid-patches)
- [Sigh-Club](https://github.com/Sigh-Club) / SighNet — the
  [SighNet DE](https://sighnet.org) community

## License

MIT. The patched source is a derivative of the game's own decompiled class
and is intended for use with a legally obtained copy of Project Zomboid.
