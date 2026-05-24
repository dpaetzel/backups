# setup-remote.fish — source this to get a ready-to-use `restic`.
#
#   source setup-remote.fish
#   restic init      # or: snapshots / backup / check / …
#
# It exports RESTIC_REPOSITORY and RESTIC_PASSWORD_FILE, and defines a
# `restic` function that injects the sftp.command (key/host/port) so you
# never pass -o / -r / --password-file by hand.

# Directory of THIS file. `status --current-filename` works while a file
# is being sourced, so this resolves correctly regardless of cwd.
set -l setup_dir (path resolve (dirname (status --current-filename)))

# ── Machine-specific connection settings ───────────────────────────────
set -l storagebox_conf "$setup_dir/storagebox.fish"
if not test -r "$storagebox_conf"
    echo "Error: missing config file: $storagebox_conf" >&2
    echo "       Copy storagebox.fish.example to storagebox.fish and edit it." >&2
    return 1
end
source "$storagebox_conf"
set -q sb_port; or set sb_port 23

if not set -q sb_user sb_host
    echo "Error: $storagebox_conf must set both sb_user and sb_host." >&2
    return 1
end
if not test -r "$identity_file"
    echo "Error: SSH identity file not readable: $identity_file" >&2
    return 1
end

set -l password_file "$setup_dir/restic-password"
if not test -r "$password_file"
    echo "Error: restic password file not readable: $password_file" >&2
    return 1
end

# ── Exported environment ───────────────────────────────────────────────
set -gx RESTIC_REPOSITORY "sftp:$sb_user@$sb_host:Backups/$hostname"
set -gx RESTIC_PASSWORD_FILE "$password_file"

# ── Shared SSH options for both restic and the log-upload sftp ─────────
# A list, so it expands to separate args. Port is passed separately
# because sftp wants -P and ssh wants -p.
set -g ssh_opts -F none -i "$identity_file" -o IdentitiesOnly=yes

# restic's sftp.command needs a single string; join the list into it. Global
# vars so the function (a separate scope) can see them.
set -g _restic_ssh_cmd "ssh $ssh_opts -p $sb_port $sb_user@$sb_host -s sftp"

function restic --description 'restic with Hetzner Storage Box sftp.command preset'
    command restic -o sftp.command="$_restic_ssh_cmd" $argv
end

echo "restic configured for $RESTIC_REPOSITORY"
