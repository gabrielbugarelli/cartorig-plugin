# CartoRig 0.6.4 — Blackmagic API contract gate

Candidate purpose: replace the failed 0.6.3 Resolve/Fusion scripting boundary with
explicit contracts derived from Blackmagic documentation and observed Lua-binding
metadata.

Automated release-to-editor gate for this development build:

- CI PASS on the exact candidate commit.
- Integration PASS on Lua 5.1 on the exact candidate commit.
- Windows package/migration/uninstall PASS on the exact candidate commit.
- The Windows artifact must identify the same commit in manifest.json,
  SHA256SUMS.txt and the installed build-info.txt.

Mandatory regression evidence:

- the exact 0.6.3 host candidate is installed first in the Windows migration test;
- its TimelineService contains raw pairs() iteration of GetItemListInTrack data;
- 0.6.4 normalizes the documented list through CartoRig.blackmagic_api;
- Resolve binding metadata __flags is represented in Lua tests but is removed only
  at the API boundary;
- any other collection key that violates the Blackmagic documented shape fails
  closed before timeline mutation;
- GetMarkers, GetMarkInOut and Fusion GetToolList use their own documented
  dictionary/table contracts rather than the item-list adapter;
- Resolve/Fusion proxy invocation is centralized; bmd module functions keep dot
  call semantics while object methods keep self/colon semantics;
- NodeFactory uses CartoRig.fusion_contract and verifies graph/post-rollback state;
- the package contains blackmagic_api.lua and fusion_contract.lua.

The 0.6.4 build is **not** a Resolve Studio host PASS. After automated gates, the
editor must install that exact artifact and repeat Create Scene in Resolve Studio
20. A01-A20/B01-B20 remain NOT RUN unless their complete normative observations
are separately executed and recorded.
