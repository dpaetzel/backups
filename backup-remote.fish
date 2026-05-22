#!/usr/bin/env fish

# A list of directories to back up.
set targets \
    "$HOME"
set exclude_file (dirname (status --current-filename))/excludes.txt
echo "Using exclude file $exclude_file …"

# ── Configuration ──────────────────────────────────────────────────────
set script_dir (dirname (status --current-filename))
source "$script_dir/setup-remote.fish"

# ── Run backup, capturing the full log ─────────────────────────────────
set timestamp (date +%Y-%m-%dT%H-%M-%S)
set log_file "$local_log_dir/backup_$timestamp.log"

begin
    echo "=== restic backup ==="
    echo "host:    $hostname"
    echo "started: "(date +%Y-%m-%dT%H:%M:%S)
    echo "repo:    $RESTIC_REPOSITORY"
    echo "targets: $targets"
    echo
    restic \
        backup $targets \
        --exclude-file "$exclude_file" \
        --exclude-caches \
        --verbose
end 2>&1 | tee "$log_file"
set restic_status $pipestatus[1]

echo "finished: "(date +%Y-%m-%dT%H:%M:%S)" — restic exit $restic_status" \
    | tee -a "$log_file"

# ── Copy the log to the storage box ────────────────────────────────────
# Logs live in Backups/<hostname>_logs, a *sibling* of the restic repo, so
# restic never sees them. -mkdir lines ignore "already exists" errors.
echo "Uploading log to $storagebox:$remote_log_dir/ …"
printf -- '-mkdir Backups\n-mkdir %s\nput %s %s/\n' \
    "$remote_log_dir" "$log_file" "$remote_log_dir" \
    | sftp $ssh_opts -P $sb_port -b - "$sb_user@$sb_host"
set sftp_status $status
if test $sftp_status -ne 0
    echo "Warning: log upload to the storage box failed (sftp exit $sftp_status)." >&2
end

# Propagate restic's exit code (3 = completed with read errors).
exit $restic_status
