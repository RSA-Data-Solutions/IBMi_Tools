#!/usr/bin/env python3
"""
Issue detection script for IBMi_Tools repository
"""

import subprocess
import sys
import os
from datetime import datetime

def check_git_issues():
    """Check for issues in Git history"""
    print("Checking Git history for potential issues...")
    
    try:
        # Get recent commits
        result = subprocess.run(['git', 'log', '--oneline', '--since="1 month ago"', '-10'], 
                              capture_output=True, text=True, check=True)
        commits = result.stdout.strip().split('\n') if result.stdout.strip() else []
        print(f"Recent commits ({len(commits)}):")
        for commit in commits:
            if commit.strip():
                print(f"  {commit}")
                
        # Look for common issue-related keywords in commit messages
        issue_keywords = ['fix', 'bug', 'issue', 'error', 'resolve', 'correct', 'patch']
        issue_commits = []
        
        for commit in commits:
            if commit.strip():
                commit_lower = commit.lower()
                if any(keyword in commit_lower for keyword in issue_keywords):
                    issue_commits.append(commit)
        
        if issue_commits:
            print(f"\nPotential issue-related commits ({len(issue_commits)}):")
            for commit in issue_commits:
                print(f"  {commit}")
        else:
            print("\nNo obvious issue-related commits found in recent history.")
            
    except subprocess.CalledProcessError as e:
        print(f"Error getting commits: {e}")
        return False
    
    return True

def check_file_changes():
    """Check for recent file changes that might indicate issues"""
    print("\nChecking recent file changes...")
    
    try:
        # Get status of changed files
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True, check=True)
        changes = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        if changes and any(change.strip() for change in changes):
            print("Modified files:")
            for change in changes:
                if change.strip():
                    print(f"  {change}")
        else:
            print("No modified files found.")
            
    except subprocess.CalledProcessError as e:
        print(f"Error getting status: {e}")
        return False
    
    return True

def create_issue_tracker():
    """Create basic issue tracking mechanism"""
    print("\nCreating basic issue tracking mechanism...")
    
    # Create an issues file
    issues_file = "ISSUES_TRACKER.md"
    with open(issues_file, 'w') as f:
        f.write("# Issues Tracker\n\n")
        f.write("## Date: " + datetime.now().strftime("%Y-%m-%d") + "\n\n")
        f.write("## Current Issues\n\n")
        f.write("| ID | Description | Priority | Status |\n")
        f.write("|----|-------------|----------|--------|\n")
        f.write("| 1 | Sample issue for demonstration | Medium | Open |\n\n")
        f.write("## Fix Cycle Process\n\n")
        f.write("1. Identify issue\n2. Assign to AI agent\n3. Fix automatically\n4. Test\n5. Merge\n")
    
    print(f"Issues tracker created: {issues_file}")

def main():
    print("Starting issue detection process for IBMi_Tools...")
    
    success = True
    success &= check_git_issues()
    success &= check_file_changes()
    create_issue_tracker()
    
    if success:
        print("\n✓ Issue detection process completed successfully!")
    else:
        print("\n✗ Some errors occurred during issue detection.")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())