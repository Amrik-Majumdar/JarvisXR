# Daemon Capability Contract

`jarvisd` exposes capability registry metadata and live availability state.

## Capability List Message

```json
{
  "type": "capabilities",
  "registry_version": "0.2.0",
  "capabilities": [
    {
      "id": "camera_inspection_001",
      "family": "Camera and Inspection",
      "name": "Scan This",
      "mode": "offline",
      "required_hardware": ["camera"],
      "risk_level": "low",
      "permission_required": "none beyond active Jarvis session"
    }
  ]
}
```

## Availability Message

```json
{
  "type": "availability",
  "offline": true,
  "online": false,
  "dock": false,
  "hardware": {
    "camera": true,
    "microphone": true,
    "gps": true,
    "sensors": true,
    "storage_free_gb": 5.4
  },
  "jailbreak": {
    "active": false,
    "ios_version": null
  }
}
```

## Safety Rule

The daemon must refuse unavailable mode and hardware requests even if the shell UI accidentally enables them.

## v0.4 Adapter Reporting

Daemon responses may include adapter status, latency, source, and error fields. Sources such as `mock_camera` or `mock_ocr` identify Windows mocks. Future sources must identify native or dock bridges explicitly.

## v0.5 XR Capability Matrix

`core/registry/xr_capability_matrix.json` classifies every registry entry for iPhone XR Device Mode. The native shell should use those classifications to explain whether a capability is available offline native, online native, dock only, soft ownership only, blocked in hard lockdown, blocked until jailbreak, or uncertain pending device tests.
