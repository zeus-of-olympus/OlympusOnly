# OlympusOnly

A player is allowed only if their guild name starts with `OLYMPUS`.

- Guild starts with `OLYMPUS`: allowed
- Any other guild: blacklisted (chat hidden, invites declined)
- No guild: blacklisted
- Guild not yet readable: left alone until the client can see it

## Install

Copy the `OlympusOnly` folder to `Interface\AddOns`.

```
AddOns\OlympusOnly\OlympusOnly.toc
AddOns\OlympusOnly\OlympusOnly.lua
```

Forever is usually:

```
World of Warcraft\_classic_beta_\Interface\AddOns\OlympusOnly\
```

## Commands

| Command | Effect |
| --- | --- |
| `/oo` | Status |
| `/oo on` / `/oo off` | Enable or disable |
| `/oo list` | Print the blacklist |
| `/oo add Name` | Force-blacklist |
| `/oo remove Name` | Remove from blacklist |
| `/oo check Name` | Look up a name |
| `/oo scan` | Classify target / mouseover / group / who |
| `/oo who` | Scan the current `/who` results |
| `/oo clearblack` | Wipe the blacklist |
| `/oo notify on\|off` | Toggle notices |
| `/oo prefix OLYMPUS` | Change the guild prefix |
