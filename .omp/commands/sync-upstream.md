# Sync Upstream Command

Pull latest changes from upstream (`can1357/oh-my-pi`), preserve fork-exclusive features, run the full test suite, and push if everything passes.

## Arguments

- `$ARGUMENTS`: Optional flags
  - `--no-push`: Run tests but do not push even if they pass
  - `--dry-run`: Fetch and merge only; skip tests and push

## Steps

### 1. Pre-flight Checks

```bash
# Ensure working tree is clean
if [ -n "$(git status --short)" ]; then
    echo "ERROR: Working tree is not clean. Commit or stash changes first."
    exit 1
fi

# Ensure on main branch
if [ "$(git branch --show-current)" != "main" ]; then
    echo "ERROR: Not on main branch."
    exit 1
fi
```

### 2. Fetch Upstream

```bash
git fetch upstream main
```

### 3. Check for New Commits

```bash
NEW_COMMITS=$(git log HEAD..upstream/main --oneline)
if [ -z "$NEW_COMMITS" ]; then
    echo "No new upstream commits. Already up to date."
    exit 0
fi

echo "New upstream commits:"
echo "$NEW_COMMITS"
```

### 4. Merge Upstream

```bash
# Perform the merge
git merge upstream/main --no-edit

# If merge conflicts occur, stop and report
if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
    echo "ERROR: Merge conflicts detected. Resolve manually:"
    git diff --name-only --diff-filter=U
    exit 1
fi
```

### 5. Preserve Fork-Exclusive Features

After merging, verify and restore the following fork-specific changes if upstream overwrote them:

**Repository references** (must point to `happyshittake/oh-my-pi`):
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/SECURITY.md`
- `AGENTS.md`
- `README.md`
- `docs/mcp-config.md`
- `packages/coding-agent/README.md`
- `packages/coding-agent/src/cli/update-cli.ts`
- `packages/coding-agent/src/config/mcp-schema.json`
- `packages/coding-agent/src/web/scrapers/discogs.ts`

Verify no `can1357/oh-my-pi` references remain:
```bash
git grep -l "can1357/oh-my-pi" -- ".github/" "*.md" "packages/coding-agent/src/" || true
```
If any are found, restore from `origin/main` before the merge:
```bash
# Example restoration
git checkout origin/main -- .github/ISSUE_TEMPLATE/config.yml .github/SECURITY.md AGENTS.md README.md docs/mcp-config.md packages/coding-agent/README.md packages/coding-agent/src/cli/update-cli.ts packages/coding-agent/src/config/mcp-schema.json packages/coding-agent/src/web/scrapers/discogs.ts
```

**Discovery (non-pi agent loading removed)**:
Ensure `packages/coding-agent/src/discovery/index.ts` does NOT import:
- `./claude`
- `./claude-plugins`
- `./cline`
- `./codex`
- `./cursor`
- `./gemini`
- `./opencode`
- `./github`
- `./vscode`
- `./windsurf`

**OAuth/API-key selector with search**:
Ensure `packages/coding-agent/src/modes/components/oauth-selector.ts` retains:
- `ProviderItem` interface with `type: "oauth" | "apiKey"`
- `Input` search component
- `apiKeyProviders` option
- `onApiKeySelect` callback
- `apiKeyStatus` callback

**Task discovery (generic agent dirs)**:
Ensure `packages/coding-agent/src/task/discovery.ts` uses `.agent`/`.agents` instead of `.pi`/`.claude`.

**Model registry API-key support**:
Ensure `packages/coding-agent/src/config/model-registry.ts` retains `saveProviderApiKey` and `removeProviderApiKey` methods.

**`.gitignore`**:
Ensure `docs/superpowers/` is present.

### 6. Regenerate Lockfile

```bash
bun install
```

### 7. Run Full Test Suite

```bash
bun test
```

If tests fail, do NOT push. Report failures and stop:
```bash
if [ $? -ne 0 ]; then
    echo "ERROR: Tests failed. Fix before pushing."
    exit 1
fi
```

### 8. Push (unless `--no-push`)

```bash
if [ "$ARGUMENTS" != "*--no-push*" ]; then
    git push origin main
fi
```

### 9. Print Summary

Generate a markdown summary with the following sections:

```markdown
## Upstream Sync Summary

### New Commits
[List each upstream commit with hash and message]

### Fork-Specific Features Preserved
- [List each preserved feature and verification status]

### Files Changed
[List files modified by the merge, grouped by package/area]

### Conflicts
[None, or list conflicted files and resolution]

### Decisions Made
- [Any manual fixes applied, version handling, etc.]

### Test Results
[Pass/Fail with counts if available]
```

## Decision Log

When performing this sync, record any decisions made:

1. **Version handling**: Upstream may bump versions. If the fork already bumped independently, keep the higher version or align with upstream depending on release strategy.
2. **Theme files**: Upstream frequently updates theme JSON files. These are usually safe to take verbatim unless the fork customized specific themes.
3. **Provider descriptors**: Upstream updates to `packages/ai/src/provider-models/descriptors.ts` should generally be accepted; fork-specific provider additions (if any) must be re-applied.
4. **Discovery removals**: The fork intentionally removes several agent-discovery imports. If upstream adds new ones, evaluate whether they belong in this fork.
5. **Changelogs**: Do not overwrite fork CHANGELOGs; append upstream changes to `[Unreleased]` if relevant.

## Rollback

If the merge introduces unexpected breakage:

```bash
git reset --hard origin/main
```

This restores the pre-merge state.

## Notes

- This fork (`happyshittake/oh-my-pi`) intentionally excludes several upstream agent-discovery integrations (Claude Desktop, Cursor, Gemini, OpenCode, GitHub, VS Code, Windsurf) and adds API-key provider support to the OAuth selector.
- Always verify these exclusions/inclusions survived the merge before pushing.
- Never push a broken merge. Tests are the gate.

## Usage

```bash
# Full sync: merge, test, push
omp sync-upstream

# Merge and test, but do not push
omp sync-upstream --no-push

# Merge only, skip tests and push
omp sync-upstream --dry-run
```

## Examples

### Successful Sync

```
$ omp sync-upstream
Fetching upstream...
3 new commits from upstream/main:
  bba00cb98 chore: bump version to 14.5.11
  21d57e8ed docs: update docs
  0da59084e feat(coding-agent): added content-based todo matching for write/commands

Merging upstream/main... done.
Verifying fork features... ok.
Regenerating lockfile... done.
Running tests... pass (TS: 142, RS: 12)
Pushing to origin/main... done.
```

### Nothing New

```
$ omp sync-upstream
No new upstream commits. Already up to date.
```

### Test Failure

```
$ omp sync-upstream
Fetching upstream...
1 new commit from upstream/main:
  abc1234 fix: breaking change in parser

Merging upstream/main... done.
Running tests... FAIL
  packages/coding-agent/test/parser.test.ts: 2 failures

Push skipped. Fix tests and re-run.
```

## Classification of Fork vs Upstream Changes

| Area | Fork Change | Upstream Change | Merge Strategy |
|---|---|---|---|
| Repo URLs | `happyshittake` | `can1357` | Keep fork |
| Discovery imports | Removed non-pi agents | May add/modify | Keep fork removals; evaluate new upstream imports |
| OAuth selector | +API-key providers, +search | May refactor UI | Preserve fork additions; apply upstream refactors carefully |
| Task discovery | `.agent`/`.agents` dirs | May update paths | Keep fork paths |
| Model registry | +API-key save/remove | May update registry | Preserve fork methods; apply upstream schema changes |
| `.gitignore` | +`docs/superpowers` | May add ignores | Union both |
| Theme JSONs | Same as upstream | Frequently updated | Take upstream unless fork customized |
| Version | Fork-specific bumps | Upstream bumps | Keep higher or align manually |
