# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Bug-fix workflow with GitHub integration (`./orchestrate.sh bug`)
- Triage, Plan, Fix, Verify phases for bug-fix workflow
- Severity-based model routing (critical/major/minor)
- GitHub issue auto-creation with labels
- Branch naming convention: `fix/<issue#>-<description>`
- PR auto-linking with `Fixes #<issue>` syntax
- Codex task templates for bug fixes (regression tests, similar fixes, docs)
- Bug-fix specific prompts: triage.md, bugfix-planner.md, verify.md
- Pre-flight checks command (`./orchestrate.sh preflight`)
- Abort command for soft stop (`./orchestrate.sh abort`)
- Rollback command for hard reset (`./orchestrate.sh rollback`)
- Autonomous mode timeout support (`./orchestrate.sh autonomous enable 4h`)
- Timeout extend command (`./orchestrate.sh autonomous extend 2h`)
- Duration parsing for timeouts (4h, 30m, 2h30m, 1d formats)

### Changed
- State.json now includes `type` field (feature/bugfix)
- State.json includes `bug` object for bug-fix metadata
- State.json includes `timeout_hours` and `expires_at` in autonomous object
- Resume command auto-detects workflow type
- Codex task cleanup now handles bugfix-*.md files
- Autonomous mode auto-disables when timeout expires
- Help text updated with new commands and options

---

## How to Add Entries

When completing a bug fix or feature, add an entry under `## [Unreleased]`:

### Entry Format

```markdown
### Added
- New feature description (#issue_number)

### Changed
- What changed and why (#issue_number)

### Fixed
- Bug fix description (#issue_number)

### Deprecated
- Feature being phased out

### Removed
- Feature removed

### Security
- Security fix description (#issue_number)
```

### Commit with CHANGELOG

```bash
# After updating CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for #<issue_number>"
```

### Release Process

When releasing a version:
1. Move items from `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`
2. Create new empty `## [Unreleased]` section
3. Tag the release: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
