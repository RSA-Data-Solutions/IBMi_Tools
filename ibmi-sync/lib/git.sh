#!/bin/bash

# IBM i Unified Sync Tool - Git Operations
# Handles Git version control and GitHub integration

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/session.sh"

# ============================================================================
# Git Repository Management
# ============================================================================

# Initialize Git repository
git_init() {
    local profile=$1

    config_load_profile "$profile"

    print_info "Initializing Git repository: $IBMI_LOCAL_DIR"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    # Check if already a git repo
    if [ -d .git ]; then
        print_warning "Repository already initialized"
        return 0
    fi

    # Initialize
    git init || die "Failed to initialize Git repository"

    # Create .gitignore if needed
    if [ ! -f .gitignore ]; then
        cat > .gitignore << 'EOF'
# Common ignore patterns
*.tmp
*.log
.DS_Store
*.swp
*.swo
*~
.vscode/
node_modules/
__pycache__/
*.pyc
.env
.env.local
EOF
        print_success "Created .gitignore"
    fi

    # Configure user if needed
    if ! git config user.name >/dev/null 2>&1; then
        local user_name=$(read_input "Git user name:" "IBM i Developer")
        git config user.name "$user_name"
    fi

    if ! git config user.email >/dev/null 2>&1; then
        local user_email=$(read_input "Git user email:" "")
        git config user.email "$user_email"
    fi

    # Add remote if configured
    if [ -n "$IBMI_GIT_REPO" ]; then
        git remote add origin "$IBMI_GIT_REPO" 2>/dev/null || true
        print_success "Added remote: $IBMI_GIT_REPO"
    fi

    # Initial commit
    git add . 2>/dev/null || true
    if [ -n "$(git status --porcelain)" ]; then
        git commit -m "Initial commit from IBM i" >/dev/null 2>&1 || true
    fi

    print_success "Git repository initialized"
    return 0
}

# ============================================================================
# Git Operations
# ============================================================================

# Get Git status
git_status() {
    local profile=$1

    config_load_profile "$profile"

    print_title "Git Status: $IBMI_LOCAL_DIR"
    print_separator

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    git status
    return $?
}

# Commit changes
git_commit() {
    local profile=$1
    local message=$2

    if [ -z "$message" ]; then
        message=$(read_input "Commit message:")
    fi

    [ -z "$message" ] && die "Commit message required"

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    print_info "Committing: $message"

    # Stage all changes
    git add -A

    # Check if there are changes
    if ! git diff --cached --quiet; then
        # Commit changes
        git commit -m "$message" || return 1
        print_success "Committed: $message"
        return 0
    else
        print_warning "No changes to commit"
        return 0
    fi
}

# Push to remote
git_push() {
    local profile=$1
    local branch=${2:-}

    config_load_profile "$profile"

    if [ -z "$IBMI_GIT_REPO" ]; then
        die "No remote repository configured"
    fi

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    if [ -z "$branch" ]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
    fi

    print_info "Pushing to: $IBMI_GIT_REPO (branch: $branch)"

    git push -u origin "$branch" || return 1

    print_success "Pushed to: $branch"
    return 0
}

# Pull from remote
git_pull() {
    local profile=$1
    local branch=${2:-}

    config_load_profile "$profile"

    if [ -z "$IBMI_GIT_REPO" ]; then
        die "No remote repository configured"
    fi

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    if [ -z "$branch" ]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
    fi

    print_info "Pulling from: $IBMI_GIT_REPO (branch: $branch)"

    git pull origin "$branch" || return 1

    print_success "Pulled from: $branch"
    return 0
}

# Show Git log
git_log() {
    local profile=$1
    local count=${2:-10}

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    print_title "Git Log (last $count commits)"
    print_separator

    git log --oneline -n "$count"

    return 0
}

# Show Git diff
git_diff() {
    local profile=$1
    local file=${2:-}

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    print_title "Git Diff"
    print_separator

    if [ -n "$file" ]; then
        git diff -- "$file"
    else
        git diff
    fi

    return 0
}

# Show/create branches
git_branch() {
    local profile=$1
    local action=${2:-list}
    local branch_name=$3

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    case "$action" in
        list)
            print_title "Branches"
            git branch -a
            ;;
        create)
            if [ -z "$branch_name" ]; then
                branch_name=$(read_input "New branch name:")
            fi
            git checkout -b "$branch_name" || return 1
            print_success "Branch created: $branch_name"
            ;;
        delete)
            if [ -z "$branch_name" ]; then
                branch_name=$(read_input "Branch to delete:")
            fi
            if ! confirm "Delete branch: $branch_name?"; then
                print_warning "Cancelled"
                return 0
            fi
            git branch -d "$branch_name" || return 1
            print_success "Branch deleted: $branch_name"
            ;;
        switch)
            if [ -z "$branch_name" ]; then
                branch_name=$(read_input "Branch to switch to:")
            fi
            git checkout "$branch_name" || return 1
            print_success "Switched to branch: $branch_name"
            ;;
        *)
            die "Invalid action: $action (list|create|delete|switch)"
            ;;
    esac

    return 0
}

# ============================================================================
# Workflow Operations
# ============================================================================

# Full sync workflow: IBM i → Local → Git → GitHub
workflow_full_sync() {
    local profile=$1
    local remote_path=$2
    local local_name=$3
    local commit_message=$4

    if [ -z "$remote_path" ] || [ -z "$local_name" ]; then
        die "Usage: workflow_full_sync <profile> <remote_path> <local_name> [message]"
    fi

    if [ -z "$commit_message" ]; then
        commit_message="Synced from IBM i: $local_name"
    fi

    config_load_profile "$profile"

    print_title "Full Sync Workflow"
    print_separator
    print_info "1. Pull from IBM i: $remote_path"
    print_info "2. Commit to Git: $commit_message"
    print_info "3. Push to GitHub"
    print_separator

    # Step 1: Pull from IBM i
    print_info "Step 1: Pulling from IBM i..."
    if ! file_sync_from "$profile" "$remote_path" "$local_name"; then
        die "Failed to pull from IBM i"
    fi

    # Initialize Git if needed
    if [ ! -d "$IBMI_LOCAL_DIR/.git" ]; then
        print_info "Initializing Git repository..."
        git_init "$profile" || die "Failed to initialize Git"
    fi

    # Step 2: Commit to Git
    print_info "Step 2: Committing to Git..."
    if ! git_commit "$profile" "$commit_message"; then
        print_warning "Nothing to commit"
    fi

    # Step 3: Push to GitHub
    print_info "Step 3: Pushing to GitHub..."
    if ! git_push "$profile"; then
        print_warning "No remote configured or push failed"
        return 1
    fi

    print_separator
    print_success "Full sync workflow completed!"

    return 0
}

# Sync and commit in one step
git_sync_commit() {
    local profile=$1
    local local_path=$2
    local remote_path=$3
    local commit_message=${4:-"Synced from IBM i"}

    config_load_profile "$profile"

    print_title "Sync and Commit"

    # Sync first
    print_info "Syncing: $remote_path → $local_path"
    file_sync_from "$profile" "$remote_path" "$local_path" || return 1

    # Then commit
    print_info "Committing..."
    git_commit "$profile" "$commit_message" || return 1

    print_success "Sync and commit completed"

    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get current branch
git_current_branch() {
    local profile=$1

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || return 1
    git rev-parse --abbrev-ref HEAD
}

# Get remote URL
git_remote_url() {
    local profile=$1

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || return 1
    git config --get remote.origin.url
}

# Check if repository has uncommitted changes
git_has_changes() {
    local profile=$1

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || return 1

    if [ -n "$(git status --porcelain)" ]; then
        return 0
    fi
    return 1
}

# Create Git tag
git_tag() {
    local profile=$1
    local tag_name=$2
    local message=${3:-}

    if [ -z "$tag_name" ]; then
        tag_name=$(read_input "Tag name:")
    fi

    [ -z "$tag_name" ] && die "Tag name required"

    config_load_profile "$profile"

    cd "$IBMI_LOCAL_DIR" || die "Failed to change directory"

    if [ -n "$message" ]; then
        git tag -a "$tag_name" -m "$message" || return 1
    else
        git tag "$tag_name" || return 1
    fi

    print_success "Tag created: $tag_name"

    if confirm "Push tag to remote?"; then
        git push origin "$tag_name" || print_warning "Failed to push tag"
    fi

    return 0
}

# ============================================================================
# Export functions
# ============================================================================

export -f git_init
export -f git_status
export -f git_commit
export -f git_push
export -f git_pull
export -f git_log
export -f git_diff
export -f git_branch
export -f workflow_full_sync
