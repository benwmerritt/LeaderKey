#!/usr/bin/env bash
# The mba13 half of lk-verify, which pipes this file to `bash -s` over SSH for every command.
# Every command but doctor and clean needs the smoke-test lock held by this run.
# Usage: bash -s <run dir> doctor|begin|set|drive|end|clean [args] < remote.sh
set -uo pipefail

run_dir="$1"
command="$2"
shift 2

domain=com.brnbw.Leader-Key
lock=/tmp/leaderkey-smoke.lock
installed="/Applications/Leader Key.app"
app="$run_dir/src/build/Leader Key.app"
evidence="$run_dir/evidence"
run_id="${run_dir##*/lk-verify-}"
marker=/private/tmp/lk-verify-marker
uid="$(id -u)"
settle="${LK_SETTLE:-1}"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

fail() {
  echo "lk-verify (mba13): $*" >&2
  exit 1
}

# pgrep -f pattern for the copy of Leader Key running from bundle $1.
pattern() {
  local executable="$1/Contents/MacOS/Leader Key"
  printf '^%s( |$)' "${executable//./[.]}"
}

running() { pgrep -u "$uid" -f "$(pattern "$1")" >/dev/null; }

# $1 running|stopped, $2 bundle, $3 half-second tries.
wait_until() {
  local tries=$3
  while ((tries-- > 0)); do
    if [[ $1 == running ]]; then running "$2" && return 0; else running "$2" || return 0; fi
    sleep 0.5
  done
  return 1
}

stop() {
  running "$1" || return 0
  pkill -u "$uid" -f "$(pattern "$1")"
  wait_until stopped "$1" 20 && return 0
  pkill -KILL -u "$uid" -f "$(pattern "$1")"
  wait_until stopped "$1" 10
}

# Right after a quit, LaunchServices can refuse to open an app with error -600; retry once.
launch() {
  open -a "$1" 2>/dev/null || {
    sleep 4
    open -a "$1"
  }
  wait_until running "$1" 20
}

# Leader Key copies running from anywhere but the installed app and this run's build.
strays() {
  pgrep -u "$uid" -lf 'Leader Key[.]app/Contents/MacOS/Leader Key' |
    grep -v -F -e "$installed/" -e "$app/" || true
}

version() {
  echo "$(defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null)" \
    "($(defaults read "$1/Contents/Info" CFBundleVersion 2>/dev/null))"
}

lock_ours() { grep -q -F -- "$run_id" "$lock/owner" 2>/dev/null; }

need_lock() { lock_ours || fail "this run does not hold $lock; run begin first"; }

need_build_running() { running "$app" || fail "this run's build is not running"; }

log_step() { printf '%s %s\n' "$(date -u +%T)" "$*" >>"$evidence/steps.log"; }

panel_on_screen() { [[ -n $("$run_dir/measure-panel" --ids) ]]; }

# A leaderkey:// URL that reaches Leader Key before it finishes launching crashes it, and every
# later URL relaunches it into the same crash. Ready means it has made its windows, then opened
# its panel on request and closed it again.
wait_ready() {
  local tries
  for tries in {1..20}; do
    running "$app" || return 1
    [[ -n $("$run_dir/measure-panel" --made) ]] && break
    sleep 0.5
  done
  sleep 1
  running "$app" || return 1
  open -g -a "$app" "leaderkey://show"
  for tries in {1..6}; do
    panel_on_screen && break
    sleep 0.5
  done
  panel_on_screen || return 1
  open -g -a "$app" "leaderkey://hide"
  for tries in {1..6}; do
    panel_on_screen || return 0
    sleep 0.5
  done
  return 1
}

# Key presses go to whichever app has focus. Leader Key hides its panel when it loses focus, so
# an on-screen Leader Key window means the keys reach it rather than some other app.
system_events() {
  panel_on_screen || fail "no Leader Key window on screen, so a key press would reach another app"
  osascript -e "tell application \"System Events\" to $1" >/dev/null
}

# The modifier that keeps the panel open after an action, as Settings stores it.
sticky_modifier() {
  case "$(defaults read "$domain" modifierKeyConfiguration 2>/dev/null)" in
  control | *optionGroupControlSticky*) echo control ;;
  *) echo option ;;
  esac
}

# $1 as an AppleScript string literal.
quoted() {
  local text="${1//\\/\\\\}"
  printf '"%s"' "${text//\"/\\\"}"
}

# Presses the activation shortcut recorded in Settings, the way a user opens the panel. Opening
# the panel is its job, so it skips the window-on-screen guard.
press_shortcut() {
  local stored code mods using=()
  stored="$(defaults read "$domain" KeyboardShortcuts_navigate 2>/dev/null)" ||
    fail "Settings has no activation shortcut on this Mac"
  code="$(sed -nE 's/.*"carbonKeyCode":([0-9]+).*/\1/p' <<<"$stored")"
  mods="$(sed -nE 's/.*"carbonModifiers":([0-9]+).*/\1/p' <<<"$stored")"
  [[ -n $code && -n $mods ]] || fail "cannot read the activation shortcut: $stored"
  ((mods & 256)) && using+=("command down")
  ((mods & 512)) && using+=("shift down")
  ((mods & 2048)) && using+=("option down")
  ((mods & 4096)) && using+=("control down")
  local script="key code $code"
  ((${#using[@]})) && script+=" using {$(
    IFS=,
    echo "${using[*]}"
  )}"
  osascript -e "tell application \"System Events\" to $script" >/dev/null
}

doctor() {
  echo "host $(hostname -s), console user $(stat -f %Su /dev/console)"
  if [[ -f $lock/owner ]]; then echo "lock held by: $(cat "$lock/owner")"; else echo "lock free"; fi
  echo "installed app $(version "$installed"), $(running "$installed" && echo running || echo "not running")"
  if [[ -d $app ]]; then
    echo "this run's build $(version "$app"), $(running "$app" && echo running || echo "not running")"
  elif [[ $run_id != none ]]; then
    echo "this run's build is missing at $app"
  fi
  local others
  others="$(strays)"
  [[ -n $others ]] && printf 'other Leader Key copies running:\n%s\n' "$others"
  echo "theme=$(defaults read "$domain" theme 2>/dev/null || echo unset)" \
    "configDir=$(defaults read "$domain" configDir 2>/dev/null || echo unset)"
  echo "activation shortcut=$(defaults read "$domain" KeyboardShortcuts_navigate 2>/dev/null ||
    echo unset) sticky modifier=$(sticky_modifier)"
}

# Undo begin, as far as it got: quit the build, put the defaults back exactly, relaunch the
# installed app if it was running, release the lock. Safe to run again.
restore() {
  local status=0
  stop "$app" || {
    echo "this run's build would not quit" >&2
    status=1
  }
  if [[ -f $run_dir/defaults-before.plist || -f $run_dir/defaults-absent ]]; then
    # import merges into what is there, so clear the domain first.
    defaults delete "$domain" 2>/dev/null
    if [[ -f $run_dir/defaults-before.plist ]]; then
      defaults import "$domain" "$run_dir/defaults-before.plist"
      defaults export "$domain" "$run_dir/defaults-after.plist"
      plutil -convert xml1 -o "$run_dir/defaults-before.xml" "$run_dir/defaults-before.plist"
      plutil -convert xml1 -o "$run_dir/defaults-after.xml" "$run_dir/defaults-after.plist"
      if diff "$run_dir/defaults-before.xml" "$run_dir/defaults-after.xml"; then
        echo "Leader Key defaults restored exactly"
      else
        echo "Leader Key defaults differ from the snapshot at $run_dir/defaults-before.plist" >&2
        status=1
      fi
    else
      echo "Leader Key had no defaults before the run; cleared them"
    fi
  fi
  rm -f "$marker"
  if [[ $(cat "$run_dir/installed-was-running" 2>/dev/null) == yes ]] && ! running "$installed"; then
    if launch "$installed"; then
      echo "installed app relaunched: $(version "$installed")"
    else
      echo "the installed app did not relaunch; open $installed by hand" >&2
      status=1
    fi
  fi
  if lock_ours; then
    rm -rf "$lock"
    echo "lock released"
  fi
  return $status
}

begin() {
  local theme="$1" config="$2"
  [[ -d $app ]] || fail "no build at $app; did stage succeed?"
  [[ -f $config ]] || fail "no config at $config"
  if ! mkdir "$lock" 2>/dev/null; then
    echo "lock held by: $(cat "$lock/owner" 2>/dev/null)" >&2
    exit 75
  fi
  echo "$run_id $(date -u +%FT%TZ)" >"$lock/owner"
  trap 'echo "begin failed; restoring" >&2; restore; exit 1' ERR
  local others
  others="$(strays)"
  if [[ -n $others ]]; then
    printf 'another Leader Key copy is running; quit it or ask its owner:\n%s\n' "$others" >&2
    false
  fi
  mkdir -p "$evidence" "$run_dir/config"
  if running "$installed"; then
    echo yes >"$run_dir/installed-was-running"
    stop "$installed"
  else
    echo no >"$run_dir/installed-was-running"
  fi
  if defaults export "$domain" "$run_dir/defaults-before.plist" 2>/dev/null; then :; else
    rm -f "$run_dir/defaults-before.plist"
    touch "$run_dir/defaults-absent"
  fi
  rm -f "$marker"
  local config_file="$run_dir/config/config.${config##*.}"
  cp "$config" "$config_file"
  defaults write "$domain" theme "$theme"
  defaults write "$domain" configDir "$run_dir/config"
  # Keep Sparkle from checking, or installing a release over this build, while it runs.
  defaults write "$domain" SUEnableAutomaticChecks -bool false
  caffeinate -u -t 2 &
  launch "$app"
  wait_ready || {
    echo "the build never showed its panel" >&2
    false
  }
  trap - ERR
  log_step "begin theme=$theme config=$config"
  echo "running $(version "$app") with theme $theme and $config_file"
}

set_default() {
  need_lock
  defaults write "$domain" "$@"
  stop "$app"
  launch "$app" || fail "this run's build did not relaunch"
  wait_ready || fail "the relaunched build never showed its panel"
  log_step "set $*"
  echo "set $1 and relaunched the build"
}

open_url() {
  open -g -a "$app" "$1"
  sleep "$settle"
}

# screencapture needs Screen Recording for SSH sessions on this Mac; without it, it fails.
capture() {
  local file="$1"
  shift
  if ! screencapture -x "$@" "$file" 2>/dev/null || [[ ! -s $file ]]; then
    fail "could not save $file: give Screen Recording to /usr/libexec/sshd-keygen-wrapper" \
      "in System Settings > Privacy & Security on $(hostname -s)"
  fi
  echo "saved $file"
}

shot() {
  local ids name="$1" n=0
  ids="$("$run_dir/measure-panel" --ids)"
  [[ -n $ids ]] || fail "shot $name: no on-screen Leader Key window"
  for id in $ids; do
    local file="$evidence/$name.png"
    ((n++ > 0)) && file="$evidence/$name-$n.png"
    capture "$file" -o -l"$id"
  done
}

drive() {
  need_lock
  need_build_running
  local step
  while (($#)); do
    step="$1"
    shift
    case "$step" in
    show | hide | reset | activate | settings | config-reload | about)
      open_url "leaderkey://$step"
      ;;
    navigate | url | key | sticky | running | quit | wait | measure | shot | screen)
      (($#)) || fail "$step needs an argument"
      case "$step" in
      navigate) open_url "leaderkey://navigate?keys=$1" ;;
      url) open_url "$1" ;;
      key)
        system_events "keystroke $(quoted "$1")"
        sleep "$settle"
        ;;
      sticky)
        system_events "keystroke $(quoted "$1") using $(sticky_modifier) down"
        sleep "$settle"
        ;;
      running)
        if pgrep -u "$uid" -xq "$1"; then echo "$1: running"; else echo "$1: not running"; fi |
          tee -a "$evidence/measure.log"
        ;;
      quit) osascript -e "tell application $(quoted "$1") to quit" >/dev/null ;;
      wait) sleep "$1" ;;
      measure) "$run_dir/measure-panel" "$1" | tee -a "$evidence/measure.log" ;;
      shot) shot "$1" ;;
      screen) capture "$evidence/$1.png" -m ;;
      esac
      log_step "$step $1"
      shift
      continue
      ;;
    marker)
      if [[ -e $marker ]]; then echo "marker: present"; else echo "marker: absent"; fi |
        tee -a "$evidence/measure.log"
      ;;
    shortcut) press_shortcut && sleep "$settle" ;;
    backspace) system_events 'key code 51' && sleep "$settle" ;;
    escape) system_events 'key code 53' && sleep "$settle" ;;
    return) system_events 'key code 36' && sleep "$settle" ;;
    *) fail "unknown step: $step" ;;
    esac
    log_step "$step"
  done
}

clean() {
  [[ $run_dir == /private/tmp/lk-verify-* ]] || fail "refusing to remove $run_dir"
  lock_ours && fail "this run still holds the lock; run end first"
  running "$app" && fail "this run's build is still running; run end first"
  # Forget every copy of the app in the run, so leaderkey:// links never open a deleted build.
  find "$run_dir" -name 'Leader Key.app' -type d -prune -exec "$lsregister" -u {} \; 2>/dev/null
  rm -rf "$run_dir"
  echo "removed $run_dir"
}

case "$command" in
doctor) doctor ;;
begin) begin "$@" ;;
set) set_default "$@" ;;
drive) drive "$@" ;;
end)
  need_lock
  restore
  ;;
clean) clean ;;
*) fail "unknown command: $command" ;;
esac
