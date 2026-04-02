# to-canonical-xmi

Transforms UML class models from **Enterprise Architect (EA) XMI** and
**Eclipse UML2 XMI** to **Canonical XMI** as defined by OMG XMI 2.5.1 Annex B,
scoped to the UCMIS (UML Class Model Interoperable Subset).

---

## Purpose

Different UML modelling tools serialise XMI in incompatible ways — EA adds
proprietary extension blocks, Eclipse UML2 uses its own namespace and element
conventions, and neither follows the OMG Canonical XMI format required for
interoperability. This stylesheet normalises any supported input to a single,
tool-neutral Canonical XMI form that can be reliably consumed, compared, and
versioned across tools and organisations.

### What the stylesheet does

- Promotes the selected root package to a `uml:Model` root element
- Strips all tool-specific wrapper elements and extension blocks
- Converts all structural properties to child elements per Canonical XMI B.6
- Enforces canonical property ordering on all element types per B.5
- Suppresses default multiplicity values (`lowerValue=1`, `upperValue=1`) per B.7
- Generates deterministic `xmi:id` and `xmi:uuid` values from per-package
  `PackageInformation` prefix and namespace URI declarations
- Resolves primitive type references to the correct OMG or Eclipse URI per B.8
- Qualifies association names as `SubjectClass_verb_ObjectClass`
- Passes through Standard Profile stereotype applications
  (`StandardProfile:Derive/Refine/Trace`) as top-level `xmi:XMI` children
- Passes through external UML profile stereotype applications

### Supported UML metaclasses (UCMIS subset)

`uml:Model`, `uml:Package`, `uml:Class`, `uml:DataType`, `uml:Enumeration`,
`uml:PrimitiveType`, `uml:Association`, `uml:Dependency`, `uml:Abstraction`,
`uml:Property` (ownedAttribute and ownedEnd), `uml:EnumerationLiteral`,
`uml:Comment`, `uml:Generalization`.

Elements of types outside this subset are suppressed with a `[WARNING]` message.

### Canonical XMI B requirements met

All mandatory requirements of OMG XMI 2.5.1 Annex B are met within the UCMIS
subset: correct root element and namespace declarations (B.2), deterministic
`xmi:id` and `xmi:uuid` (B.3), `xmi:type` on all elements (B.4), canonical
child element ordering (B.5), attribute-to-element conversion (B.6), default
multiplicity suppression (B.7), and `href` for primitive type references (B.8).

---

## Requirements

- **Java 11 or later** (Java 21 recommended)
- **Saxon HE 12** — bundled in the fat JAR; supply separately for direct stylesheet use

## Downloads

- [Java fat Jar](target/to-canonical-xmi-1.0.0.jar)
- [Linux script](to-canonical-xmi.sh) or [Windows script](to-canonical-xmi.bat) - both require the fat Jar
- [to-canonical-xmi.xslt](xslt/to-canonical-xmi.xslt) - only required if used directly with a XSLT processor

---

## Documentation

- [Implementor Specification](doc/to-canonical-xmi-spec.md)
- [XSLTDoc Documentation](doc/xsltdoc)
- Generating the XSLTDoc documentation: `./mvnw.sh generate-resources -P xsltdoc`

---

## Export XMI from Enterprise Architect

Menu path in version 17.1: Publish / Export / Export to Other Format - Other Formats  
The 'Publish Model Package' window opens.

- Package: select model or package
- Filename: select file for XMI export
- XML Type: select 'UML 2.5 (XMI 2.5.1)'
- General Options
  - Uncheck 'Export Diagrams'
  - Uncheck 'Exclude EA Extensions'

Click 'Export'  
Progress should say: XMI Document Export Complete!

---

## Usage — stylesheet directly (Saxon command line)

Use this approach when integrating into an existing Saxon-based pipeline or
when you want to use your own Saxon installation.

### Basic invocation

```bash
java -jar saxon-he-12.x.jar \
  -s:input.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:output.xmi
```

### Parameters

All parameters are optional. Defaults match standard behaviour.

| Parameter | Default | Description |
|---|---|---|
| `generateIds` | `yes` | Generate deterministic `xmi:id` and `xmi:uuid` from `PackageInformation`. Set to `no` to preserve source ids. |
| `namespaceURI` | *(empty)* | Override the namespace URI for `xmi:uuid` generation across all packages. When empty, the `URI` attribute of each package is used. |
| `namespacePrefix` | *(empty)* | Override the prefix for `xmi:id` generation across all packages. When empty, the `prefix` from each package's `PackageInformation` DataType is used. |
| `qualifiedAssocNames` | `yes` | Derive association names as `SubjectClass_verb_ObjectClass`. Set to `no` to preserve source names. |
| `sourceHasQualifiedNames` | `no` | Set to `yes` if the source already has qualified association names. The stylesheet preserves them and only validates, warning on mismatch. |
| `sourcePackageName` | *(empty)* | Name of a specific package to promote to the `uml:Model` root. When empty, the first top-level package is used (EA) or the existing `uml:Model` (Eclipse). |
| `input` | *(auto-detect)* | Override input flavour: `ea`, `eclipse`, or `generic`. When empty, the flavour is auto-detected from namespace declarations and extension blocks. |
| `eclipseOutput` | `no` | Set to `yes` to use Eclipse UML namespace and primitive type URIs in the output. Default uses OMG URIs. |
| `profilePrefix` | *(empty)* | Namespace prefix of an external UML profile whose stereotype applications should be passed through (e.g. `schemaProfile`). When empty, no external profile processing is done. |
| `profileNamespaceURI` | *(empty)* | Override the namespace URI for the external profile. When empty, the URI is discovered from the root element namespace declarations. Error if not found. |

### Examples

```bash
# EA input, auto-detected, OMG output namespace (default)
java -jar saxon-he-12.x.jar \
  -s:model.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# Eclipse input, OMG output namespace
java -jar saxon-he-12.x.jar \
  -s:model.uml \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  input=eclipse \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# EA input, Eclipse output namespace
java -jar saxon-he-12.x.jar \
  -s:model.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  eclipseOutput=yes \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# EA input with external profile stereotype pass-through
java -jar saxon-he-12.x.jar \
  -s:model.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib" \
  profilePrefix=schemaProfile \
  "profileNamespaceURI=http://ucmis.org/profiles/schema/1.0"

# Promote a named package to uml:Model root
java -jar saxon-he-12.x.jar \
  -s:model.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  sourcePackageName=MyModel \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# Eclipse input, Eclipse output namespace (round-trip)
java -jar saxon-he-12.x.jar \
  -s:model.uml \
  -xsl:to-canonical-xmi.xslt \
  -o:canonical.xmi \
  input=eclipse \
  eclipseOutput=yes \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"
```

---

## Usage — launcher scripts (fat JAR)

The fat JAR bundles Saxon HE 12 and the stylesheet. Only Java 11 or later
is required. No Maven or separate Saxon installation needed.

### Launcher scripts

Place both the launcher script and `to-canonical-xmi-1.0.0.jar` in the same
directory.

| Platform | Script | Make executable |
|---|---|---|
| Linux / macOS | `to-canonical-xmi.sh` | `chmod +x to-canonical-xmi.sh` (once) |
| Windows | `to-canonical-xmi.bat` | no setup needed |

### Run (Linux/macOS)

```bash
chmod +x to-canonical-xmi   # once only

./to-canonical-xmi.sh \
  -s:input.xmi \
  -o:output.xmi \
  [parameter=value ...]
```

### Run (Windows)

```cmd
to-canonical-xmi.bat -s:input.xmi -o:output.xmi [parameter=value ...]
```

### Run directly with Java (all platforms)

```bash
java -jar to-canonical-xmi-1.0.0.jar \
  -s:input.xmi \
  -o:output.xmi \
  [parameter=value ...]
```

### Examples

```bash
# EA input, OMG output (Linux/macOS)
./to-canonical-xmi.sh \
  -s:model.xmi \
  -o:canonical.xmi \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# Eclipse input (Linux/macOS)
./to-canonical-xmi.sh \
  -s:model.uml \
  -o:canonical.xmi \
  input=eclipse \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# EA input with Eclipse output namespace (Linux/macOS)
./to-canonical-xmi.sh \
  -s:model.xmi \
  -o:canonical.xmi \
  eclipseOutput=yes \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib"

# EA input with external profile (Linux/macOS)
./to-canonical-xmi.sh \
  -s:model.xmi \
  -o:canonical.xmi \
  namespacePrefix=LIB \
  "namespaceURI=http://example.org/lib" \
  profilePrefix=schemaProfile \
  "profileNamespaceURI=http://ucmis.org/profiles/schema/1.0"

# Windows equivalent
to-canonical-xmi.bat ^
  -s:model.xmi ^
  -o:canonical.xmi ^
  namespacePrefix=LIB ^
  "namespaceURI=http://example.org/lib"

# Show built-in help
./to-canonical-xmi.sh --help
```

### Build the fat JAR from source

```bash
# Linux/macOS — make wrapper executable once
chmod +x mvnw

./mvnw.sh clean package
# Produces: target/to-canonical-xmi-1.0.0.jar

# Windows
mvnw.cmd clean package
```

Maven is downloaded automatically on first run (~10 MB) and cached in
`~/.m2/wrapper/dists/`. Subsequent builds use the cached installation.

---

## Usage — Maven wrapper (build pipeline integration)

The Maven wrapper invokes Saxon directly from the project classpath.
No separate Maven installation is required.

### Run the transform

```bash
# Linux/macOS
chmod +x mvnw    # once only
./mvnw.sh exec:java \
  -Dxslt.input=model.xmi \
  -Dxslt.output=canonical.xmi \
  -Dxslt.namespacePrefix=LIB \
  "-Dxslt.namespaceURI=http://example.org/lib"

# Windows
mvnw.cmd exec:java ^
  -Dxslt.input=model.xmi ^
  -Dxslt.output=canonical.xmi ^
  -Dxslt.namespacePrefix=LIB ^
  "-Dxslt.namespaceURI=http://example.org/lib"
```

Maven wrapper parameters use the `-Dxslt.` prefix:

| Stylesheet parameter | Maven wrapper property |
|---|---|
| `generateIds` | `-Dxslt.generateIds=yes\|no` |
| `namespaceURI` | `"-Dxslt.namespaceURI=http://..."` |
| `namespacePrefix` | `-Dxslt.namespacePrefix=LIB` |
| `qualifiedAssocNames` | `-Dxslt.qualifiedAssocNames=yes\|no` |
| `sourceHasQualifiedNames` | `-Dxslt.sourceHasQualifiedNames=yes\|no` |
| `sourcePackageName` | `-Dxslt.sourcePackageName=MyPackage` |
| `input` | `-Dxslt.input.flavour=ea\|eclipse\|generic` |
| `eclipseOutput` | `-Dxslt.eclipseOutput=yes\|no` |
| `profilePrefix` | `-Dxslt.profilePrefix=schemaProfile` |
| `profileNamespaceURI` | `"-Dxslt.profileNamespaceURI=http://..."` |

### Examples

```bash
# Eclipse input with Eclipse output namespace
./mvnw.sh exec:java \
  -Dxslt.input=model.uml \
  -Dxslt.output=canonical.xmi \
  -Dxslt.input.flavour=eclipse \
  -Dxslt.eclipseOutput=yes \
  -Dxslt.namespacePrefix=LIB \
  "-Dxslt.namespaceURI=http://example.org/lib"

# EA input with external profile
./mvnw.sh exec:java \
  -Dxslt.input=model.xmi \
  -Dxslt.output=canonical.xmi \
  -Dxslt.namespacePrefix=LIB \
  "-Dxslt.namespaceURI=http://example.org/lib" \
  -Dxslt.profilePrefix=schemaProfile \
  "-Dxslt.profileNamespaceURI=http://ucmis.org/profiles/schema/1.0"

# Promote named package to uml:Model root
./mvnw.sh exec:java \
  -Dxslt.input=model.xmi \
  -Dxslt.output=canonical.xmi \
  -Dxslt.sourcePackageName=MyModel \
  -Dxslt.namespacePrefix=LIB \
  "-Dxslt.namespaceURI=http://example.org/lib"
```

---

## PackageInformation

Per-package `xmi:id` prefix and `xmi:uuid` namespace URI are resolved from a
`PackageInformation` `uml:DataType` placed as a direct child of any package.
Inner packages override outer ones. The global `namespacePrefix` and
`namespaceURI` parameters always take priority.

Add a `PackageInformation` DataType to each package in your model with a
`prefix` attribute whose default value is the desired id prefix:

```
uml:Package  name="MyPackage"  URI="http://example.org/mypackage"
  └── uml:DataType  name="PackageInformation"
        └── uml:Property  name="prefix"  defaultValue="MyPkg"
```

All elements within `MyPackage` (and nested packages without their own
`PackageInformation`) will receive:

- `xmi:id` = `MyPkg.<elementName>`
- `xmi:uuid` = `http://example.org/mypackage#<elementName>`

---

## Input auto-detection

When `input` is not set, the flavour is detected automatically:

| Detected condition | Flavour |
|---|---|
| `xmi:Extension[@extender='Enterprise Architect']` present | `ea` |
| `xmi:Documentation[@exporter='Enterprise Architect']` present | `ea` |
| Root or model element namespace = Eclipse UML URI | `eclipse` |
| None of the above | `generic` (with warning) |

---

## License

Apache License, Version 2.0
