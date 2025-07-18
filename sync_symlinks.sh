#!/bin/zsh

WORK_DIR="~"
ARTIFACTS_DIR="00a_artifacts"
BACKUP_DIR="00b_artifacts_backup"
EXTENSIONS=(npz pkl csv pt pth ckpt h5)
LOG_FILE="$WORK_DIR/symlink_sync.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >>"$LOG_FILE"
    echo "$1"
}

cd "$WORK_DIR" || exit 1

# Create main artifacts directory and subdirectories for each file type
mkdir -p "$ARTIFACTS_DIR"
chmod 755 "$ARTIFACTS_DIR"

for ext in $EXTENSIONS; do
    mkdir -p "$ARTIFACTS_DIR/$ext"
    chmod 755 "$ARTIFACTS_DIR/$ext"
done

# STEP 1: Clean up broken/orphaned symlinks AND symlinks to non-existent files
log_message "Cleaning up broken symlinks and orphaned symlinks..."
for ext in $EXTENSIONS; do
    for symlink in $ARTIFACTS_DIR/$ext/*(@N); do
        if [[ ! -e "$symlink" ]] || [[ ! -f "$(readlink "$symlink")" ]]; then
            rm "$symlink" 2>/dev/null
            log_message "Removed orphaned symlink: ${symlink:t}"
        fi
    done
done

# STEP 2: Build current valid symlinks set
typeset -A existing_symlinks
for ext in $EXTENSIONS; do
    for existing in $ARTIFACTS_DIR/$ext/*(@N); do
        if [[ -f "$existing" ]]; then
            existing_symlinks[${existing:t}]=1
        fi
    done
done

log_message "Starting artifact search..."

# STEP 3: Find and create new symlinks
timeout 600 find -L . -maxdepth 15 \
    -path "./$ARTIFACTS_DIR" -prune -o \
    -path "*/site-packages/*" -prune -o \
    -path "*/lib/*" -prune -o \
    -path "*/lib64/*" -prune -o \
    -path "*/share/*" -prune -o \
    -path "*/bin/*" -prune -o \
    -path "*/include/*" -prune -o \
    -path "*/.git/*" -prune -o \
    -path "*/node_modules/*" -prune -o \
    -path "*/__pycache__/*" -prune -o \
    -path "*/.venv/*" -prune -o \
    -path "*/venv/*" -prune -o \
    -path "*/env/*" -prune -o \
    -path "./00b_artifacts_backup" -prune -o \
    -type f \( -name "*.npz" -o -name "*.pkl" -o -name "*.csv" -o -name "*.pt" -o -name "*.pth" -o -name "*.ckpt" -o -name "*.h5" \) -print |
    while read -r file; do
        file=${file#./}

        # Skip files in artifacts directory
        if [[ "$file" == "$ARTIFACTS_DIR"/* ]]; then
            continue
        fi

        dir=${file%%/*}
        filename=${file:t}
        extension=${filename:e}

        # Skip if we can't read the file
        if [[ ! -r "$file" ]]; then
            log_message "WARNING: Skipping unreadable file: $file"
            continue
        fi

        # SKIP if this file itself is a symlink
        if [[ -L "$file" ]]; then
            log_message "Skipping symlinked file: $file"
            continue
        fi

        # Get first 3 characters of directory name
        dir_prefix=${dir:0:3}

        content_hash=$(md5sum "$file" 2>/dev/null | cut -c1-8)
        if [[ -z "$content_hash" ]]; then
            log_message "WARNING: Could not hash file: $file"
            continue
        fi

        # New naming: {first3chars}_{hash}_{filename}
        symlink_name="${dir_prefix}_${content_hash}_${filename}"

        if [[ -z ${existing_symlinks[$symlink_name]} ]]; then
            if ln -s "$PWD/$file" "$ARTIFACTS_DIR/$extension/${symlink_name}" 2>/dev/null; then
                # Make the target file readable by all users
                chmod 644 "$file" 2>/dev/null || log_message "WARNING: Could not change permissions for: $file"
                log_message "Created in $extension/: ${symlink_name}"
            else
                log_message "ERROR: Failed to create symlink for: $file"
            fi
        fi
    done

# Check if timeout occurred
if [[ $? -eq 124 ]]; then
    log_message "ERROR: Search timed out after 10 minutes"
fi

# STEP 4: Make all artifact files world-readable
log_message "Setting permissions on artifact files..."
for ext in $EXTENSIONS; do
    for symlink in $ARTIFACTS_DIR/$ext/*(@N); do
        if [[ -f "$symlink" ]]; then
            chmod 644 "$symlink" 2>/dev/null || true
        fi
    done
done

log_message "Starting backup of new files..."

mkdir -p "$BACKUP_DIR"
chmod 755 "$BACKUP_DIR"

# Create subdirectories for each file type in backup
for ext in $EXTENSIONS; do
    mkdir -p "$BACKUP_DIR/$ext"
    chmod 755 "$BACKUP_DIR/$ext"
done

# Get list of existing backups to avoid duplicates
typeset -A existing_backups
for ext in $EXTENSIONS; do
    for backup in $BACKUP_DIR/$ext/*(.N); do
        if [[ -f "$backup" ]]; then
            existing_backups[${backup:t}]=1
        fi
    done
done

# Copy new files from artifacts to backup
backup_count=0
for ext in $EXTENSIONS; do
    for symlink in $ARTIFACTS_DIR/$ext/*(@N); do
        if [[ -f "$symlink" ]]; then
            symlink_name=${symlink:t}

            # Only backup if we don't already have this file
            if [[ -z ${existing_backups[$symlink_name]} ]]; then
                target_file=$(readlink "$symlink")
                if [[ -f "$target_file" ]] && cp "$target_file" "$BACKUP_DIR/$ext/$symlink_name" 2>/dev/null; then
                    chmod 444 "$BACKUP_DIR/$ext/$symlink_name"
                    log_message "Backed up: $ext/$symlink_name"
                    ((backup_count++))
                else
                    log_message "WARNING: Failed to backup: $ext/$symlink_name"
                fi
            fi
        fi
    done
done

log_message "Backup completed: $backup_count new files backed up"

chmod 444 "$BACKUP_DIR"/$ext/* 2>/dev/null || true # Files: read-only for all
chmod 555 "$BACKUP_DIR"/$ext 2>/dev/null || true   # Subdirs: read + execute only
chmod 555 "$BACKUP_DIR" 2>/dev/null || true        # Main backup dir: read + execute

chmod 555 "$ARTIFACTS_DIR"
for ext in $EXTENSIONS; do
    chmod 555 "$ARTIFACTS_DIR/$ext"
done

log_message "ML artifacts synchronization completed"
