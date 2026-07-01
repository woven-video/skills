#!/usr/bin/env bash
set -euo pipefail

CATALOG_BASE="${WOVEN_SFX_SITE_URL:-https://www.woven.video/sfx}"
ASSET_BASE="${SFX_CDN_BASE:-https://assets.sfx.woven.video}"

expand_home() {
  local p="$1"
  case "$p" in
    "~") echo "$HOME" ;;
    "~/"*) echo "${HOME}${p:1}" ;;
    *) echo "$p" ;;
  esac
}

resolve_library_dir() {
  if [[ -n "${WOVEN_SFX_LIBRARY:-}" ]]; then
    local expanded
    expanded="$(expand_home "$WOVEN_SFX_LIBRARY")"
    if [[ "$expanded" = /* ]]; then
      echo "$expanded"
    else
      echo "$(pwd)/$expanded"
    fi
    return
  fi

  if [[ -n "${1:-}" ]]; then
    local expanded
    expanded="$(expand_home "$1")"
    if [[ "$expanded" = /* ]]; then
      echo "$expanded"
    else
      echo "$(pwd)/$expanded"
    fi
    return
  fi

  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    local project_md="$dir/.claude/project.md"
    if [[ -f "$project_md" ]]; then
      local line
      line="$(grep -E '^sfx-library:' "$project_md" | head -1 | sed 's/^sfx-library:[[:space:]]*//')"
      if [[ -n "$line" ]]; then
        local expanded
        expanded="$(expand_home "$line")"
        if [[ "$expanded" = /* ]]; then
          echo "$expanded"
        else
          echo "$dir/$expanded"
        fi
        return
      fi
      break
    fi
    dir="$(dirname "$dir")"
  done

  echo "$(pwd)/sounds/sfx"
}

LIB_DIR="$(resolve_library_dir "${1:-}")"
mkdir -p "$LIB_DIR"

echo "Pulling sounds from $CATALOG_BASE → $LIB_DIR"

CATALOG=$(curl -fsSL "${CATALOG_BASE%/}/catalog.json")
node -e "
const fs=require('fs');const path=require('path');const https=require('https');const http=require('http');
const catalog=JSON.parse(process.argv[1]);const lib=process.argv[2];const assetBase=(process.argv[3]||'').replace(/\/+$/,'');
function resolveUrl(url){return url.startsWith('/')?assetBase+url:url;}
async function dl(url, dest) {
  if (fs.existsSync(dest)) { console.log('  skip ' + path.basename(dest)); return; }
  const resolved=resolveUrl(url);
  await new Promise((res,rej)=>{(resolved.startsWith('https')?https:http).get(resolved,r=>{if(r.statusCode&&r.statusCode>=400){rej(new Error(resolved+' → '+r.statusCode));return;}const d=[];r.on('data',c=>d.push(c));r.on('end',()=>{fs.writeFileSync(dest,Buffer.concat(d));res();});}).on('error',rej);});
}
(async()=>{for(const s of catalog.sounds){await dl(s.url, path.join(lib,s.file));console.log('  '+s.id);}})().catch(e=>{console.error(e);process.exit(1);});
" "$CATALOG" "$LIB_DIR" "$ASSET_BASE"

echo ""
echo "✓ Library ready at $LIB_DIR"
