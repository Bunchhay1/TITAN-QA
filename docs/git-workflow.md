# Git Workflow

## Branch Strategy
- `main` - stable, tested code
- `feature/*` - new test features
- `fix/*` - bug fixes

## Commit Convention
```
type: short description

Types: feat, fix, docs, test, chore, ci, config, build, tooling, refactor
```

## PR Process
1. Create feature branch
2. Write tests
3. Open PR to main
4. CI must pass
5. Merge after review
