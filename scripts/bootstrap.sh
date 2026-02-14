#!/usr/bin/env bash
set -euo pipefail

echo "==> Init submodules"
git submodule update --init --recursive

echo "==> Done"
echo ""
echo "Next:"
echo "  - Backend:  cd backend"
echo "  - Frontend: cd frontend"
echo "  - Runner:   cd runner"
