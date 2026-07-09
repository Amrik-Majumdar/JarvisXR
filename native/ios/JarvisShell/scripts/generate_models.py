from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
REGISTRY = ROOT / "core" / "registry" / "capabilities.json"
SCHEMAS = ROOT / "core" / "daemon" / "schemas"
OUT = Path(__file__).resolve().parents[1] / "generated"


MODELS = {
    "JVSCapability": [
        ("identifier", "NSString *"),
        ("family", "NSString *"),
        ("name", "NSString *"),
        ("mode", "NSString *"),
        ("riskLevel", "NSString *"),
        ("requiredHardware", "NSArray<NSString *> *"),
    ],
    "JVSCommandRequest": [
        ("requestId", "NSString *"),
        ("type", "NSString *"),
        ("command", "NSString *"),
        ("mode", "NSString *"),
        ("confirmationToken", "NSString *"),
    ],
    "JVSCommandResponse": [
        ("requestId", "NSString *"),
        ("status", "NSString *"),
        ("mode", "NSString *"),
        ("spokenResponse", "NSString *"),
        ("displayResponse", "NSString *"),
        ("riskLevel", "NSString *"),
        ("requiresConfirmation", "BOOL"),
        ("unavailableReason", "NSString *"),
        ("data", "NSDictionary *"),
    ],
    "JVSPhoneState": [
        ("profile", "NSString *"),
        ("network", "NSDictionary *"),
        ("battery", "NSDictionary *"),
        ("storage", "NSDictionary *"),
        ("camera", "NSDictionary *"),
        ("microphone", "NSDictionary *"),
        ("sensors", "NSDictionary *"),
        ("privacy", "NSDictionary *"),
        ("jailbreak", "NSDictionary *"),
    ],
    "JVSMode": [
        ("name", "NSString *"),
        ("available", "BOOL"),
        ("unavailableReason", "NSString *"),
    ],
    "JVSConfirmation": [
        ("token", "NSString *"),
        ("riskLevel", "NSString *"),
        ("createdAt", "NSTimeInterval"),
        ("expiresAt", "NSTimeInterval"),
        ("used", "BOOL"),
    ],
}


def header(name: str, fields: list[tuple[str, str]]) -> str:
    props = []
    for field, objc_type in fields:
        attr = "assign" if objc_type in {"BOOL", "NSTimeInterval"} else "copy"
        if objc_type in {"NSDictionary *", "NSArray<NSString *> *"}:
            attr = "copy"
        props.append(f"@property (nonatomic, {attr}) {objc_type}{field};")
    return "\n".join(
        [
            "// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.",
            "#import <Foundation/Foundation.h>",
            "",
            f"@interface {name} : NSObject",
            *props,
            "- (instancetype)initWithDictionary:(NSDictionary *)dictionary;",
            "@end",
            "",
        ]
    )


def implementation(name: str, fields: list[tuple[str, str]]) -> str:
    assigns = []
    for field, objc_type in fields:
        key = "id" if field == "identifier" else field
        if objc_type == "BOOL":
            assigns.append(f"        _{field} = [dictionary[@\"{key}\"] boolValue];")
        elif objc_type == "NSTimeInterval":
            assigns.append(f"        _{field} = [dictionary[@\"{key}\"] doubleValue];")
        else:
            assigns.append(f"        _{field} = [dictionary[@\"{key}\"] copy];")
    return "\n".join(
        [
            "// Generated skeleton for JarvisOS iPhone 6. Do not treat as compiled proof.",
            f"#import \"{name}.h\"",
            "",
            f"@implementation {name}",
            "- (instancetype)initWithDictionary:(NSDictionary *)dictionary {",
            "    self = [super init];",
            "    if (self) {",
            *assigns,
            "    }",
            "    return self;",
            "}",
            "@end",
            "",
        ]
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    with REGISTRY.open("r", encoding="utf-8") as handle:
        registry = json.load(handle)
    schema_names = sorted(path.name for path in SCHEMAS.glob("*.json"))
    metadata = {
        "registry_version": registry["version"],
        "capability_count": len(registry["capabilities"]),
        "schemas": schema_names,
        "note": "Generated Objective-C skeletons for future native UIKit bridge.",
    }
    (OUT / "GENERATION_METADATA.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    for name, fields in MODELS.items():
        (OUT / f"{name}.h").write_text(header(name, fields), encoding="utf-8")
        (OUT / f"{name}.m").write_text(implementation(name, fields), encoding="utf-8")
    print(f"Generated {len(MODELS) * 2} Objective-C skeleton files in {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
