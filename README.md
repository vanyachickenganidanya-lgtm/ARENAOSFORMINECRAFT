# AuroraOS - GitHub hosting

Pastebin blocks this kind of code, so we host the files on GitHub and the OS / installer download from `raw.githubusercontent.com`.

## Files to put in the repo
- `aurora_os.lua`   (the OS itself)
- `installer.lua`   (one-command installer)
- `version.txt`     (contains just the version number, e.g. `3.0`)

## Step 1 - create the repo
1. Go to github.com -> New repository, name it `auroraos` (Public).
2. Add files via "Add file -> Upload files" (drag-drop all three). Commit.

## Step 2 - get the raw URLs
For a file in the repo click it, then the **Raw** button. The URL looks like:
```
https://raw.githubusercontent.com/USER/auroraos/main/aurora_os.lua
```
Replace `USER` with your GitHub username (and `auroraos`/`main` if you named them differently).

## Step 3 - put the URL into the code
In BOTH `aurora_os.lua` and `installer.lua` replace the placeholder:
```
https://raw.githubusercontent.com/USER/auroraos/main/...
```
with your real URL. Then commit again.

## Step 4 - install on any computer (one command)
On a CC: Tweaked computer with a disk drive / network:
```
wget run https://raw.githubusercontent.com/USER/auroraos/main/installer.lua
```
It asks: mode (console/graphics), color, admin name, password. Downloads `aurora_os.lua` to `/startup`, writes config, reboots.

## Step 5 - updates
- Edit `version.txt` to the new version (e.g. `3.1`) and re-upload `aurora_os.lua`.
- The OS checks `version.txt` on boot and shows an "UPDATE" button / `update` command re-downloads `aurora_os.lua` and reboots.

## If downloads fail
The server must allow HTTP and the domain. In the CC:T config (`config/computercraft-common.toml` or server rules):
- `http.enabled = true`
- allow `raw.githubusercontent.com` (if an allowlist is set, add it; if the allowlist is empty, all domains are allowed).

Note: GitHub raw sometimes needs a minute to refresh after a commit; if a download returns old content, wait ~1 min and retry.
