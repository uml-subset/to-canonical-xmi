# to-canonical-xmi.xslt — Implementor Specification {#to-canonical-xmixslt-implementor-specification}

**Version:** 1.0  
**Author:** joachim.wackerow@posteo.de  
**Copyright:** Joachim Wackerow  
**Processor:** Saxon-HE 12 (XSLT 2.0, no extensions)  
**File:** `to-canonical-xmi.xslt`  
**Reference:** OMG XMI 2.5.1, <https://www.omg.org/spec/XMI/2.5.1/PDF>  

**Test environment:** Enterprise Architect Corporate Edition 17.1 Build 1716 64-bit,
XML export option (UML 2.5 / XMI 2.5.1), exporter version 6.5, exporter ID 1716;
Eclipse UML2; Java 21; Saxon-HE 12.0.

---

## Table of Contents {#table-of-contents}

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Terminology](#2-terminology)
3. [Namespaces](#3-namespaces)
4. [Parameters](#4-parameters)
5. [Input Formats](#5-input-formats)
6. [Processing Architecture](#6-processing-architecture)
7. [Phase 1 — Extension Tree Builder (EA only)](#7-phase-1-extension-tree-builder-ea-only)
8. [Phase 2 — Preprocess Mode](#8-phase-2-preprocess-mode)
9. [Phase 3 — Canonical Pass](#9-phase-3-canonical-pass)
10. [Namespace and Prefix Resolution](#10-namespace-and-prefix-resolution)
11. [Identifier Generation](#11-identifier-generation)
12. [Canonical Property Ordering](#12-canonical-property-ordering)
13. [Multiplicity Handling](#13-multiplicity-handling)
14. [Primitive Type Resolution](#14-primitive-type-resolution)
15. [Association and Abstraction Name Qualification](#15-association-and-abstraction-name-qualification)
16. [Comment and Annotation Handling](#16-comment-and-annotation-handling)
17. [Cross-Reference (idref) Resolution](#17-cross-reference-idref-resolution)
18. [Suppression Rules](#18-suppression-rules)
19. [Warning and Error Reporting](#19-warning-and-error-reporting)
20. [XSL Key Declarations](#20-xsl-key-declarations)
21. [Output Specification](#21-output-specification)
22. [Standard Profile Stereotype Applications](#22-standard-profile-stereotype-applications)
23. [External Profile Stereotype Applications](#23-external-profile-stereotype-applications)
24. [Canonical XMI B Compliance](#24-canonical-xmi-b-compliance)
25. [Known Limitations](#25-known-limitations)
26. [Invocation Reference](#26-invocation-reference)

---

## 1. Purpose and Scope {#1-purpose-and-scope}

`to-canonical-xmi.xslt` transforms UML class model XMI files produced by Enterprise Architect (EA) or Eclipse UML2 into **Canonical XMI** as specified by OMG XMI 2.5.1, Annex B.

The transformation is scoped to **UCMIS** — the UML Class Model Interoperable Subset — which uses:

- Single inheritance only
- Binary directed associations
- The following UML metaclasses: `Association`, `Classifier`, `Comment`, `Dependency`, `Abstraction`, `Element`, `Enumeration`, `Generalization`, `MultiplicityElement`, `NamedElement`, `Package`, `Property`, `StructuredClassifier`, `TypedElement`
- The following `xmi:type` values in the UML namespace: `Association`, `Abstraction`, `Class`, `Comment`, `DataType`, `Dependency`, `Enumeration`, `EnumerationLiteral`, `Generalization`, `LiteralInteger`, `LiteralString`, `LiteralUnlimitedNatural`, `Model`, `Package`, `PrimitiveType`, `Property`

Elements outside this subset are suppressed with a `[WARNING]` message.

---

## 2. Terminology {#2-terminology}

| Term | Meaning |
|---|---|
| **EA** | Enterprise Architect by Sparx Systems |
| **Eclipse** | Eclipse UML2 / Eclipse Modeling Framework XMI |
| **Canonical XMI** | XMI conforming to OMG XMI 2.5.1 Annex B |
| **Intermediate tree** | A normalised in-memory XML tree produced by the preprocess phase, used as input to the canonical pass |
| **Extension tree** | A flat in-memory XML tree of EA documentation and stereotype records, extracted from `xmi:Extension` |
| **createdName** | The name component of a generated `xmi:id`, without the prefix |
| **xmi:id** | Persistent XML identifier: `prefix.createdName` |
| **xmi:uuid** | Persistent universal identifier: `namespaceURI#createdName` |
| **Input flavour** | The detected or declared input source: `ea`, `eclipse`, or `generic` |
| **PackageInformation** | A `uml:DataType` named `PackageInformation` placed as a direct child of a package to declare that package's `xmi:id` prefix |

---

## 3. Namespaces {#3-namespaces}

### Input namespaces {#input-namespaces}

- **`xmi`** —  
  `http://www.omg.org/spec/XMI/20131001`
  XMI control attributes and elements
- **`uml`** —  
  `http://www.omg.org/spec/UML/20131001`
  Standard UML elements (EA and generic input)
- **`uml`** (Eclipse) —  
  `http://www.eclipse.org/uml2/5.0.0/UML`
  Eclipse UML elements (Eclipse input)
- **`umldi`** —  
  `http://www.omg.org/spec/UML/20131001/UMLDI`
  EA diagram elements — suppressed
- **`dc`** —  
  `http://www.omg.org/spec/UML/20131001/UMLDC`
  EA diagram coordinates — suppressed

### Output namespaces {#output-namespaces}

The output `xmi:XMI` root element declares exactly two required namespaces:

```xml
<xmi:XMI
  xmlns:xmi="http://www.omg.org/spec/XMI/20131001"
  xmlns:uml="http://www.omg.org/spec/UML/20131001">

```

When `eclipseOutput=yes`, the `uml` namespace URI becomes `http://www.eclipse.org/uml2/5.0.0/UML`.

When Standard Profile stereotype applications are present, an additional namespace is declared:

```xml
xmlns:StandardProfile="http://www.omg.org/spec/UML/20131001/StandardProfile"

```

Or, when `eclipseOutput=yes`:

```xml
xmlns:Standard="http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard"

```

When external profile stereotype applications are present, the profile namespace is also declared:

```xml
xmlns:profilePrefix="profileNamespaceURI"

```

All namespace declarations appear on the `xmi:XMI` root element before any child elements.

### Primitive type hrefs {#primitive-type-hrefs}

- **OMG output** (`eclipseOutput=no`):  
  `http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#`
- **Eclipse output** (`eclipseOutput=yes`):  
  `http://www.eclipse.org/uml2/5.0.0/UML/PrimitiveTypes.xmi#`

Standard UML primitive type names used in hrefs: `Boolean`, `Integer`, `Real`, `String`, `UnlimitedNatural`.

---

## 4. Parameters {#4-parameters}

All parameters are `xs:string`. Boolean parameters use the values `yes` and `no`.

| Parameter | Default | Description |
|---|---|---|
| `generateIds` | `yes` | If `yes`, generate deterministic `xmi:id` and `xmi:uuid` values. If `no`, pass through source ids with collision warnings. |
| `namespaceURI` | *(empty)* | Overrides the namespace URI for all packages. If empty, resolved per package from the `URI` attribute of that package element. Takes priority over per-package resolution. |
| `namespacePrefix` | *(empty)* | Overrides the namespace prefix for all packages. If empty, resolved per package from `PackageInformation`. Takes priority over per-package resolution. |
| `qualifiedAssocNames` | `yes` | If `yes`, association and abstraction names are output as `SubjectClass_shortName_ObjectClass`. |
| `sourceHasQualifiedNames` | `no` | If `yes`, the source already has qualified names. The stylesheet preserves them and validates, warning on mismatch. |
| `sourcePackageName` | *(empty)* | Name of a package to promote to `uml:Model` root. If empty, the first sub-package (EA) or existing `uml:Model` (Eclipse/generic) is used. |
| `input` | *(empty)* | Override input flavour detection: `ea`, `eclipse`, or `generic`. If empty, auto-detection applies. |
| `eclipseOutput` | `no` | If `yes`, use Eclipse UML namespace and primitive type URIs in the output. Independent of `input`. |
| `profilePrefix` | *(empty)* | Namespace prefix of an external UML profile whose stereotype applications should be passed through. If empty, no external profile processing is done. |
| `profileNamespaceURI` | *(empty)* | Override the namespace URI for the external profile. If empty, discovered from the root element namespace declarations. An `[ERROR]` is emitted if the URI cannot be determined. |

---

## 5. Input Formats {#5-input-formats}

### 5.1 Input flavour detection {#51-input-flavour-detection}

The stylesheet determines the input flavour before processing:

1. If `input=ea` → flavour is `ea`
2. If `input=eclipse` → flavour is `eclipse`
3. If `input=generic` → flavour is `generic`
4. Else if `/xmi:XMI/xmi:Extension[@extender='Enterprise Architect']` or  
   `/xmi:XMI/xmi:Documentation[@exporter='Enterprise Architect']` is present → `ea`
6. Else if the root element namespace or any `uml:Model` namespace is the Eclipse UML URI → `eclipse`
7. Otherwise → `generic` (warning emitted)

Unrecognised `input` parameter values fall back to auto-detection with a `[WARNING]`.

### 5.2 Enterprise Architect XMI {#52-enterprise-architect-xmi}

EA produces XMI with these structural characteristics:

- Root element: `xmi:XMI`
- Wrapper `uml:Model[@name='EA_Model']` containing top-level  
  `packagedElement[@xmi:type='uml:Package']` elements
- Documentation in `xmi:Extension/elements/element/properties/@documentation` and  
  `xmi:Extension/connectors/connector/documentation/@value`
- Standard Profile Abstraction stereotype data in  
  `xmi:Extension/connectors/connector[properties/@ea_type='Abstraction'][properties /@stereotype=('Derive','Refine','Trace')]`
- EA primitive types as `xmi:idref` values like `EAJava_Integer`, `EAJava_String`
- UML properties serialised as XML attributes, not child elements
- External profile stereotype applications as direct children of `xmi:XMI` in the profile namespace
- Source file encoding typically `windows-1252` (Saxon re-encodes to UTF-8 transparently)

**EA Association pattern:** Directed associations have one navigable end as `ownedAttribute` on the target class (carrying `@association`) and one non-navigable end as `ownedEnd` on the Association. Both appear in `memberEnd`.

**EA Abstraction pattern:** `packagedElement[@xmi:type='uml:Abstraction']` with `@supplier` and `@client` as XML attributes. The Standard Profile stereotype name (`Derive`, `Refine`, or `Trace`) is read from the EA Extension connector's `properties/@stereotype` attribute.

**EA Dependency pattern:** `packagedElement[@xmi:type='uml:Dependency']` with `@supplier` and `@client` as XML attributes.

### 5.3 Eclipse UML2 XMI {#53-eclipse-uml2-xmi}

Eclipse input characteristics:

- Root element: either `xmi:XMI` (with `uml:Model` child) or `uml:Model` directly
- No `xmi:Extension` block
- UML properties may be serialised as XML attributes
- `xmi:type` may be absent on some elements (inferred from element local name)
- Association `memberEnd` serialised as a space-separated XML attribute value, not child elements
- Standard Profile stereotype applications as direct children of `xmi:XMI` in the Eclipse Standard namespace
- External profile stereotype applications as direct children of `xmi:XMI`
- Namespace URI is `http://www.eclipse.org/uml2/5.0.0/UML`

### 5.4 Generic XMI {#54-generic-xmi}

Any input not matching EA or Eclipse is treated as generic. A `[WARNING]` is emitted. The generic preprocess performs a minimal structural pass, preserving UML elements and attributes for the canonical pass.

---

## 6. Processing Architecture {#6-processing-architecture}

```
Source XMI
    │
    ▼
Phase 1: buildExtensionTree (EA only)
    │  ──> $extTree (documentation and stereotype records)
    │
    ▼
Phase 2: Preprocess mode (ea / eclipse / generic)
    │  ──> $intermediateTree (normalised, flavour-neutral UML tree)
    │
    ▼
Phase 3: Canonical pass (mode="canonical")
    │  ──> Final output (Canonical XMI)

```

All three results are XSLT 2.0 temporary trees bound to `xsl:variable`. The intermediate tree and extension tree are passed to the canonical pass as tunnel parameters. The canonical pass is entirely flavour-agnostic; all tool-specific logic is confined to the preprocess modes.

---

## 7. Phase 1 — Extension Tree Builder (EA only) {#7-phase-1-extension-tree-builder-ea-only}

Named template `buildExtensionTree` produces a flat `<extensionData>` tree containing three record types:

**`<elementDoc>` records** — documentation for classes, packages, attributes etc.:

```xml
<elementDoc idref="EAID_xxx" documentation="Documentation text"/>

```

**`<connectorDoc>` records** — documentation for associations and dependencies:

```xml
<connectorDoc idref="EAID_xxx" documentation="Documentation text"/>

```

**`<stereotypeDoc>` records** — Standard Profile stereotype for Abstraction connectors:

```xml
<stereotypeDoc idref="EAID_xxx" stereotype="Refine"/>

```

Source: `xmi:Extension/connectors/connector[properties/@ea_type='Abstraction'] [properties/@stereotype=('Derive','Refine','Trace')]`.

Accessed in the canonical pass via three-argument `key()`:

```xslt
key('extElementByIdref',   $id, $extTree)
key('extConnectorByIdref', $id, $extTree)
key('extStereotypeByIdref', $id, $extTree)

```

---

## 8. Phase 2 — Preprocess Mode {#8-phase-2-preprocess-mode}

### 8.1 EA preprocess (`mode="ea-preprocess"`) {#81-ea-preprocess-modeea-preprocess}

| Task | Detail |
|---|---|
| **Root promotion** | Selects root package as `uml:Model`. Default: first `packagedElement[@xmi:type='uml:Package']` under EA wrapper. Override: `sourcePackageName` (recursive search). Terminates with `[ERROR]` if not found. |
| **EA wrapper suppression** | `uml:Model[@name='EA_Model']` suppressed. |
| **Extension block suppression** | `xmi:Extension` and `xmi:Documentation` suppressed silently. |
| **Diagram suppression** | `umldi:*` and `dc:*` elements suppressed silently. |
| **EA primitive types suppression** | Packages with ids starting `EAPrimitiveTypesPackage` or `EAJavaTypesPackage`, or named `EA_PrimitiveTypes_Package` or `EA_Java_Types_Package`, suppressed silently. |
| **Primitive type resolution** | EA Java primitive `xmi:idref` values resolved to canonical UML `href` values via `primitiveTypeMap`. |
| **ownedComment injection** | Synthetic `<ownedComment _body="..." _annotatedElementId="..."/>` inserted for elements with documentation in the extension tree. |
| **memberEnd normalisation** | Not required for EA (already child elements in EA source). |
| **generalization normalisation** | `@general` XML attribute converted to `<general xmi:idref="..."/>` child element. |
| **_stereotype injection** | For each `uml:Abstraction`, a `<_stereotype name="Derive|Refine|Trace"/>` synthetic child is injected if a `stereotypeDoc` record exists for the element's id. |
| **External profile stereotypes** | Top-level `xmi:XMI` children in the external profile namespace (matched by `namespace-uri-for-prefix($profilePrefix, xmi:XMI)`) collected as `<_externalStereoApp>` synthetic elements via `normaliseExternalStereoApp`. |
| **Unrecognised types** | `packagedElement` with unrecognised `xmi:type` emits `[WARNING]` and is suppressed. |

### 8.2 Eclipse preprocess (`mode="eclipse-preprocess"`) {#82-eclipse-preprocess-modeeclipse-preprocess}

| Task | Detail |
|---|---|
| **Root detection** | `xmi:XMI` root: uses first `uml:Model` child (warning if multiple). `uml:Model` root: uses directly. |
| **Root promotion** | If `sourcePackageName` set, promotes named package to `uml:Model`. |
| **memberEnd normalisation** | Space-separated `@memberEnd` attribute on Association converted to child `<memberEnd xmi:idref="..."/>` elements. |
| **xmi:type inference** | Missing `xmi:type` inferred from element local name via `elementTypeMap`. |
| **Namespace suppression** | Non-UML, non-XMI elements suppressed, except Standard Profile namespace and external profile namespace. |
| **Standard Profile stereotypes** | `Standard:Derive/Refine/Trace` elements converted to `<_stereotypeApplication stereotypeName="...">` synthetic elements with `<base_Abstraction xmi:idref="..."/>` child. |
| **External profile stereotypes** | Elements in external profile namespace collected as `<_externalStereoApp>` synthetic elements. |

### 8.3 Generic preprocess (`mode="generic-preprocess"`) {#83-generic-preprocess-modegeneric-preprocess}

Minimal pass: promotes first `uml:Model`, suppresses non-UML namespace elements, copies all UML elements and attributes. No comment injection, type inference, or primitive resolution.

---

## 9. Phase 3 — Canonical Pass {#9-phase-3-canonical-pass}

Operates on the intermediate tree. Tunnel parameters available to all templates:

| Tunnel parameter | Type | Content |
|---|---|---|
| `nsURI` | `xs:string` | Effective namespace URI for current package scope |
| `prefix` | `xs:string` | Effective namespace prefix for current package scope |
| `extTree` | `node()` | Extension tree root (EA only) |
| `intermediateRoot` | `node()` | Root of the intermediate tree |
| `sourceRoot` | `node()` | Root of the source document |

The `nsURI` and `prefix` tunnel parameters are re-evaluated at each `emitPackage` and `emitModel` call using `resolvePackageNsURI` and `resolvePackagePrefix` respectively (see Section 10). Overriding values are passed via `<xsl:with-param ... tunnel="yes"/>` to all children, so inner packages automatically use their own resolved prefix.

**Root template** emits `xmi:XMI` with namespace declarations, then `uml:Model`, then Standard Profile stereotype applications, then external profile stereotype applications (see Sections 22 and 23).

**Dispatch** in the canonical pass is driven by `@xmi:type` on `packagedElement`.

**Attribute emission order** (B.2.5): `xmi:id`, `xmi:uuid`, `xmi:type` — always in this order, always before any child element content.

**Attribute-to-element conversion:** All UML properties arriving as XML attributes in the intermediate tree are emitted as child elements in the canonical pass. The only permitted XML attributes on output elements are `xmi:id`, `xmi:uuid`, and `xmi:type`.

---

## 10. Namespace and Prefix Resolution {#10-namespace-and-prefix-resolution}

### 10.1 Per-package prefix resolution {#101-per-package-prefix-resolution}

Prefix resolution is performed at each package level by `resolvePackagePrefix`, called from `emitPackage` and the `uml:Model` canonical template. The resolved `$localPrefix` is passed as an overriding `$prefix` tunnel parameter to all children of that package.

Resolution order (first non-empty wins):

1. `namespacePrefix` global parameter
2. `defaultValue/@value` of `ownedAttribute[@name='prefix']` inside a direct-child `packagedElement[@xmi:type='uml:DataType'][@name='PackageInformation']` of the current package
3. Inherited `$prefix` tunnel parameter from the parent package

This means `PackageInformation` in an inner package overrides the prefix established by an outer package, and the global `namespacePrefix` parameter overrides everything.

### 10.2 Per-package namespace URI resolution {#102-per-package-namespace-uri-resolution}

URI resolution is performed at each package level by `resolvePackageNsURI`, called from `emitPackage` and the `uml:Model` canonical template. The resolved `$localNsURI` is passed as an overriding `$nsURI` tunnel parameter to all children.

Resolution order (first non-empty wins):

1. `namespaceURI` global parameter
2. `URI` attribute of the current package element in the intermediate tree
3. Inherited `$nsURI` tunnel parameter from the parent package

### 10.3 Cross-package idref prefix resolution {#103-cross-package-idref-prefix-resolution}

When `resolveIdref` computes the canonical `xmi:id` for a referenced element, it calls `computeElementPrefix` to determine the correct prefix for that element regardless of the caller's own package context. This ensures that references from stereotype application elements (which run in the root context, not inside any package's `apply-templates`) resolve correctly.

`computeElementPrefix` looks up the target element in the source document, finds its ancestor packages (innermost first using `ancestor::*` natural order), and calls `findInnermostPrefix` to return the prefix from the nearest enclosing package that has a `PackageInformation` DataType.

---

## 11. Identifier Generation {#11-identifier-generation}

### 11.1 `xmi:id` generation (`generateIds=yes`) {#111-xmiid-generation-generateidsyes}

Pattern: `<prefix>.<createdName>`

| Element | createdName pattern |
|---|---|
| `packagedElement` (Class, DataType, Enum, PrimitiveType, Package, Dependency) | `@name` |
| `packagedElement` (Association/Abstraction, `qualifiedAssocNames=yes`) | `SubjectClass_shortName_ObjectClass` |
| `packagedElement` (Association/Abstraction, `qualifiedAssocNames=no`) | `@name` |
| `ownedAttribute` (named) | `ParentName-attributeName` |
| `ownedAttribute` (anonymous) | `ParentName-ownedAttribute-N` |
| `ownedEnd` | `AssociationName-ownedEnd-TypeClassName` (type class name as discriminator; positional fallback `-1`, `-2` if type unresolvable) |
| `generalization` | `ClassName-generalization` |
| `ownedLiteral` | `EnumerationName-literalName` |
| `ownedComment` (first) | `OwnerName-ownedComment` |
| `ownedComment` (N-th, N>1) | `OwnerName-ownedComment-N` |
| `lowerValue` | `PropertyCreatedName-lowerValue` |
| `upperValue` | `PropertyCreatedName-upperValue` |
| `defaultValue` | `PropertyCreatedName-defaultValue` |
| StandardProfile stereotype application | `AbstractionCreatedName-StereotypeName` |
| External profile stereotype application | `stereoLocalName-resolvedBaseId` |

Character safety: `replace($name, '[^A-Za-z0-9_\-\.]', '_')` applied before assembly.

### 11.2 `xmi:uuid` generation (`generateIds=yes`) {#112-xmiuuid-generation-generateidsyes}

Pattern: `<namespaceURI>#<createdName>` (same `createdName` as for `xmi:id`).

### 11.3 Pass-through mode (`generateIds=no`) {#113-pass-through-mode-generateidsno}

Source ids passed through unchanged. Warnings emitted for duplicate ids and ids containing hyphens.

---

## 12. Canonical Property Ordering {#12-canonical-property-ordering}

All elements are emitted with properties in a hard-coded order following Canonical XMI B.5.2 (superclass properties before subclass properties). The B.5.3 override (nested before link elements) applies within `uml:Association`.

### Property order by element type {#property-order-by-element-type}

**`uml:Model` and `uml:Package`:**
1. `ownedComment`
2. `name`
3. `URI`
4. `packagedElement` (sorted by `@xmi:type` then `@xmi:uuid`)

**`uml:Class`:**
1. `ownedComment`
2. `name`
3. `isAbstract` (only if `true`)
4. `generalization`
5. `ownedAttribute`

**`uml:DataType`:**
1. `ownedComment`
2. `name`
3. `isAbstract` (only if `true`)
4. `ownedAttribute`

**`uml:Enumeration`:**
1. `ownedComment`
2. `name`
3. `isAbstract` (only if `true`)
4. `ownedAttribute`
5. `ownedLiteral`

**`uml:PrimitiveType`:**
1. `ownedComment`
2. `name`

**`uml:Association`:**
1. `ownedComment`
2. `name`
3. `ownedEnd` (nested — precedes `memberEnd` per B.5.3)
4. `memberEnd` (self-closing `xmi:idref`)

**`uml:Dependency` and `uml:Abstraction`:**
1. `ownedComment`
2. `name`
3. `client` (self-closing `xmi:idref`)
4. `supplier` (self-closing `xmi:idref`)

**`uml:Property` (ownedAttribute and ownedEnd):**
1. `ownedComment`
2. `name` (omitted if absent or empty)
3. `isReadOnly` (only if `true`)
4. `isDerived` (only if `true`)
5. `type`
6. `lowerValue`
7. `upperValue`
8. `defaultValue`
9. `association` (self-closing `xmi:idref`, required by B.2.12)
10. `aggregation` (only if non-default: `shared` or `composite`)

**`uml:Generalization`:**
1. `ownedComment`
2. `general`

**`uml:EnumerationLiteral`:**
1. `ownedComment`
2. `name`

**`uml:Comment`:**
1. `body`
2. `annotatedElement`

### `packagedElement` sorting {#packagedelement-sorting}

Sorted within each package by `@xmi:type` then `@xmi:uuid` (B.5.1).

### Boolean property defaults {#boolean-property-defaults}

Boolean properties are omitted when `false` or absent. Only `true` values are emitted, in lowercase per B.2.13. Affected: `isAbstract`, `isReadOnly`, `isDerived`.

---

## 13. Multiplicity Handling {#13-multiplicity-handling}

| Source value | `lowerValue` output | `upperValue` output |
|---|---|---|
| Absent | Omit element | Omit element |
| `1` | Omit element | Omit element |
| `0` | Emit `<value>0</value>` | n/a |
| `-1` | n/a | Emit `<value>*</value>` |
| `*` | n/a | Emit `<value>*</value>` |
| Any other | Emit `<value>N</value>` | Emit `<value>N</value>` |

- `lowerValue` is always typed `uml:LiteralInteger`
- `upperValue` is always typed `uml:LiteralUnlimitedNatural`
- `defaultValue` elements always emit their `<value>` child when `@value` is present; assumed `uml:LiteralString` if `xmi:type` absent

---

## 14. Primitive Type Resolution {#14-primitive-type-resolution}

### EA primitive type mapping {#ea-primitive-type-mapping}

EA Java primitive `xmi:idref` values are resolved to canonical UML `href` references during the EA preprocess.

| Source name | Canonical UML name |
|---|---|
| `Integer`, `int` | `Integer` |
| `String`, `string` | `String` |
| `Boolean`, `boolean` | `Boolean` |
| `Real`, `Double`, `double`, `Float`, `float` | `Real` |
| `UnlimitedNatural` | `UnlimitedNatural` |

User-defined `PrimitiveType` elements remain as same-file `xmi:idref` references.

### href normalisation {#href-normalisation}

In the canonical pass, all `href` values in `type` and `general` elements are inspected by `canonical-ref`. Both the Eclipse and OMG primitive type base URIs are recognised and rewritten to `$UML_PRIMITIVES_BASE` (driven by `eclipseOutput`). This ensures correct output regardless of the input source's primitive type URI.

---

## 15. Association and Abstraction Name Qualification {#15-association-and-abstraction-name-qualification}

When `qualifiedAssocNames=yes`, association and abstraction names in the output are replaced with:

```
SubjectClass_shortName_ObjectClass

```

### Association endpoint identification {#association-endpoint-identification}

- `memberEnd[1]` = navigable (object/destination) end, typed as the target class
- `memberEnd[2]` = non-navigable (subject/source) end, typed as the source class

The subject and object class names are resolved by looking up the `memberEnd` elements in the source document via `key('elementById', $me1idref, $sourceRoot)`. The type's `@name` or `@type` attribute gives the class name. Both `xmi:idref` and unprefixed `@type` forms are handled for Eclipse input.

### Abstraction endpoint identification {#abstraction-endpoint-identification}

For `uml:Abstraction`, the client (`@client`) and supplier (`@supplier`) attributes are resolved directly from the source document. No `memberEnd` lookup is required.

### Short name derivation {#short-name-derivation}

If `sourceHasQualifiedNames=yes`, the middle portion of the existing name is extracted by splitting on `_` and taking all tokens except first and last. Otherwise, the full source name is used as the short name.

### Behaviour when `sourceHasQualifiedNames=yes` {#behaviour-when-sourcehasqualifiednamesyes}

The source name is preserved and used in the output. Re-derivation is performed for validation only. A `[WARNING]` is emitted if the derived name differs from the source name (and class names were successfully resolved). If class names cannot be resolved, no warning is emitted.

---

## 16. Comment and Annotation Handling {#16-comment-and-annotation-handling}

### EA comment injection {#ea-comment-injection}

During EA preprocess, a synthetic `ownedComment` is injected as the first child:

```xml
<ownedComment xmi:type="uml:Comment"
              _annotatedElementId="sourceXmiId"
              _body="Documentation text"/>

```

Body text source priority: `element/properties/@documentation` → `connector/documentation/@value`. First non-empty value wins.

### Canonical comment output {#canonical-comment-output}

```xml
<ownedComment xmi:id="prefix.OwnerName-ownedComment"
              xmi:uuid="nsURI#OwnerName-ownedComment"
              xmi:type="uml:Comment">
  <body>Documentation text</body>
  <annotatedElement xmi:idref="resolvedOwnerId"/>
</ownedComment>

```

Body resolution priority: `@_body` → child `body` element → text content.

### Opposite property requirement (B.2.12) {#opposite-property-requirement-b212}

Every `ownedAttribute` and `ownedEnd` that is an association end carries  
`<association xmi:idref="assocId"/>`.

---

## 17. Cross-Reference (idref) Resolution {#17-cross-reference-idref-resolution}

All `xmi:idref` values in the canonical output pass through the `resolveIdref` named template.

### Pass-through mode (`generateIds=no`) {#pass-through-mode-generateidsno}

Source id returned unchanged.

### Generation mode (`generateIds=yes`) {#generation-mode-generateidsyes}

1. Look up element by source id in the intermediate tree: `key('interById', $sourceId, $intermediateRoot)`
2. If not found: fall back to source document: `key('elementById', $sourceId, $sourceRoot)`
3. If still not found: emit `[WARNING]`, return source id
4. If found: call `computeCreatedName` on the found element, then call `computeElementPrefix` to determine the element's own package prefix (independent of caller context), return `concat($targetPrefix, '.', $createdName)`

### `computeElementPrefix` {#computeelementprefix}

When `resolveIdref` is called from contexts outside the normal package traversal (e.g. from stereotype application emission at the root level), the inherited `$prefix` tunnel parameter reflects the root context rather than the target element's package. `computeElementPrefix` corrects this by:

1. Looking up the target element in the source document
2. Collecting `ancestor::*[@xmi:type=('uml:Package','uml:Model')]` (naturally innermost-first)
3. Calling `findInnermostPrefix` to return the prefix from the nearest enclosing package that has a `PackageInformation` DataType with a non-empty `prefix` value
4. Falling back to the inherited `$prefix` if no such ancestor is found

### Affected serialisation points {#affected-serialisation-points}

| Serialisation point | Source of the raw id |
|---|---|
| `type xmi:idref` | `type/@xmi:idref` in intermediate tree |
| `general xmi:idref` | `general/@xmi:idref` in intermediate tree |
| `association xmi:idref` | `@association` attribute |
| `memberEnd xmi:idref` | `memberEnd/@xmi:idref` in intermediate tree |
| `client xmi:idref` | `@client` attribute |
| `supplier xmi:idref` | `@supplier` attribute |
| `annotatedElement xmi:idref` | `@_annotatedElementId` or `@annotatedElement` |
| `base_Abstraction xmi:idref` | `_stereotypeApplication/base_Abstraction/ @xmi:idref` |
| `base_XXX xmi:idref` | `_externalStereoApp/@baseIdref` |

---

## 18. Suppression Rules {#18-suppression-rules}

| Suppressed content | Scope | Warning |
|---|---|---|
| `xmi:Extension` block | EA preprocess | None |
| `xmi:Documentation` element | EA preprocess | None |
| `umldi:*` and `dc:*` elements | EA preprocess, generic-copy | None |
| EA wrapper `uml:Model[@name='EA_Model']` | EA preprocess | None |
| EA primitive type packages | EA preprocess | None |
| Unrecognised `packagedElement[@xmi:type]` | Canonical dispatch | `[WARNING]` |
| Elements outside UML/XMI/Standard Profile/external profile namespaces | Eclipse preprocess | None |
| Default boolean properties (`false`) | Canonical pass | None |
| Default multiplicity (`1`) | `emitLowerValue`/`emitUpperValue` | None |
| `PackageInformation` DataType | Canonical pass — output as regular `uml:DataType` | None |

---

## 19. Warning and Error Reporting {#19-warning-and-error-reporting}

Format: `[LEVEL] Message text`. `[ERROR]` uses `terminate="yes"`.

| Level | Condition | Message |
|---|---|---|
| `[WARNING]` | Input flavour unrecognised | `Input flavour not recognised as EA or Eclipse. Proceeding with generic conversion.` |
| `[WARNING]` | Unrecognised `input` parameter value | `Unrecognised value for parameter 'input': '...'. Valid values: ea, eclipse, generic. Falling back to auto-detection.` |
| `[WARNING]` | Multiple `uml:Model` in Eclipse root | `Multiple uml:Model elements found in Eclipse xmi:XMI root — using first.` |
| `[WARNING]` | Unmapped EA primitive type | `Unmapped primitive type name '...'. Passing through unchanged.` |
| `[WARNING]` | Unresolvable `xmi:idref` | `Cannot resolve xmi:id '...' in either intermediate or source tree. Using source id.` |
| `[WARNING]` | Unrecognised `packagedElement[@xmi:type]` | `Unrecognised packagedElement type '...' — suppressing element '...'.` |
| `[WARNING]` | Qualified association name mismatch | `Qualified association name mismatch: source='...' derived='...'. Using source name.` |
| `[WARNING]` | Qualified abstraction name mismatch | `Qualified abstraction name mismatch: source='...' derived='...'. Using source name.` |
| `[WARNING]` | Cannot resolve client/supplier class names | `Cannot resolve client/supplier class names for Abstraction '...'. Using source name unchanged.` |
| `[WARNING]` | No prefix found | `No namespace prefix found (...). Falling back to model name '...'.` |
| `[WARNING]` | PackageInformation prefix empty | `PackageInformation found but prefix value is empty. Falling back to model name.` |
| `[WARNING]` | External stereotype missing base_XXX | `External profile stereotype element '...' has no base_XXX attribute — skipping.` |
| `[ERROR]` | Root package not found (EA) | `Cannot find root package. Check sourcePackageName parameter.` |
| `[ERROR]` | `uml:Model` not found (Eclipse) | `Cannot find uml:Model in Eclipse input.` |
| `[ERROR]` | Named package not found (Eclipse) | `Cannot find package '...' in Eclipse input.` |
| `[ERROR]` | `uml:Model` not found (generic) | `Cannot find uml:Model in input.` |
| `[ERROR]` | External profile URI not found | `Cannot find namespace URI for profile prefix '...'. Declare it on the root element or supply profileNamespaceURI parameter.` |

---

## 20. XSL Key Declarations {#20-xsl-key-declarations}

Seven keys are declared at stylesheet level. Keys on temporary trees use the three-argument `key(name, value, contextNode)` form.

**Source document keys:**

- **`elementById`** — matches `*[@xmi:id]`, keyed on `@xmi:id`
- **`assocById`** — matches `packagedElement[@xmi:type='uml:Association']`, keyed on `@xmi:id`
- **`eaBuiltinPrimitiveById`** — matches EA built-in PrimitiveType elements, keyed on `@xmi:id`

**Intermediate tree keys (three-argument form):**

- **`interById`** — matches `*[@xmi:id]`, keyed on `@xmi:id`

**Extension tree keys (three-argument form):**

- **`extElementByIdref`** — matches `elementDoc`, keyed on `@idref`
- **`extConnectorByIdref`** — matches `connectorDoc`, keyed on `@idref`
- **`extStereotypeByIdref`** — matches `stereotypeDoc`, keyed on `@idref`

---

## 21. Output Specification {#21-output-specification}

### Output declaration {#output-declaration}

```xml
<xsl:output method="xml" encoding="UTF-8" indent="yes" omit-xml-declaration="no"/>

```

### Root element structure {#root-element-structure}

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xmi:XMI
  xmlns:xmi="http://www.omg.org/spec/XMI/20131001"
  xmlns:uml="http://www.omg.org/spec/UML/20131001"
  [xmlns:StandardProfile="..." if Standard Profile stereotypes present]
  [xmlns:profilePrefix="..." if external profile stereotypes present]>
  <uml:Model xmi:id="..." xmi:uuid="..." xmi:type="uml:Model">
    <name>...</name>
    <URI>...</URI>
    <!-- packagedElement children sorted by xmi:type then xmi:uuid -->
  </uml:Model>
  <!-- StandardProfile stereotype applications (if any), sorted by name then uuid -->
  <!-- External profile stereotype applications (if any), sorted by name then uuid -->
</xmi:XMI>

```

No `xmi:version` attribute on `xmi:XMI`.

---

## 22. Standard Profile Stereotype Applications {#22-standard-profile-stereotype-applications}

### Supported stereotypes {#supported-stereotypes}

`Derive`, `Refine`, and `Trace` from the OMG Standard Profile, applied to `uml:Abstraction` elements.

### Position in output {#position-in-output}

After `uml:Model`, as direct children of `xmi:XMI`. Sorted by stereotype name then `xmi:uuid`.

### EA input processing {#ea-input-processing}

The stereotype name is read from  
`xmi:Extension/connectors/connector[properties/@ea_type='Abstraction']/properties/@stereotype`. A `<_stereotype name="..."/>` synthetic child is injected into the Abstraction's intermediate tree element.

### Eclipse input processing {#eclipse-input-processing}

`Standard:Derive/Refine/Trace` elements (namespace  
`http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard`) are converted to `<_stereotypeApplication stereotypeName="...">` synthetic elements with `<base_Abstraction xmi:idref="..."/>` children in the intermediate tree root.

### Output form (OMG, `eclipseOutput=no`) {#output-form-omg-eclipseoutputno}

```xml
<StandardProfile:Derive
  xmi:id="prefix.AbstractionCreatedName-Derive"
  xmi:uuid="nsURI#AbstractionCreatedName-Derive"
  xmlns:StandardProfile="http://www.omg.org/spec/UML/20131001/StandardProfile">
  <base_Abstraction xmi:idref="prefix.AbstractionCreatedName"/>
</StandardProfile:Derive>

```

### Output form (Eclipse, `eclipseOutput=yes`) {#output-form-eclipse-eclipseoutputyes}

```xml
<Standard:Derive
  xmi:id="prefix.AbstractionCreatedName-Derive"
  xmi:uuid="nsURI#AbstractionCreatedName-Derive">
  <base_Abstraction xmi:idref="prefix.AbstractionCreatedName"/>
</Standard:Derive>

```

The namespace declaration appears on the `xmi:XMI` root element, not on individual stereotype elements.

---

## 23. External Profile Stereotype Applications {#23-external-profile-stereotype-applications}

### Configuration {#configuration}

Activated when `profilePrefix` is non-empty. The namespace URI is resolved from:

1. `profileNamespaceURI` parameter (if set)
2. `namespace-uri-for-prefix($profilePrefix, root-element)` on the source document root
3. If neither resolves: `[ERROR]` is emitted

The resolved URI is stored in the stylesheet variable `$effectiveProfileNsURI`.

### EA input processing {#ext-ea-input-processing}

Top-level `xmi:XMI` children whose namespace URI matches `namespace-uri-for-prefix($profilePrefix, xmi:XMI)` in the source document are collected. The source namespace URI and the `profileNamespaceURI` override are independent: the source is matched by the source URI, but the output uses `$effectiveProfileNsURI`.

Each collected element is processed by `normaliseExternalStereoApp` into a `<_externalStereoApp>` synthetic element carrying:

- `@stereotypeName` — local name of the stereotype element
- `@baseAttrName` — name of the `base_XXX` attribute (e.g. `base_Association`)
- `@baseIdref` — value of the `base_XXX` attribute (source `xmi:id`)

### Eclipse input processing {#ext-eclipse-input-processing}

Elements in `$effectiveProfileNsURI` that are top-level `xmi:XMI` children (or siblings of `uml:Model`) are processed identically via `normaliseExternalStereoApp`.

### Output form {#output-form}

```xml
<profilePrefix:stereotypeName
  xmi:id="prefix.stereotypeName-resolvedBaseId"
  xmi:uuid="nsURI#stereotypeName-resolvedBaseId">
  <base_XXX xmi:idref="resolvedBaseId"/>
</profilePrefix:stereotypeName>

```

The `base_XXX` element name is taken from `@baseAttrName` on the synthetic element. The `xmi:idref` value is the canonical id of the referenced element, resolved via `resolveIdref`.

### Position in output {#ext-position-in-output}

After Standard Profile elements, as direct children of `xmi:XMI`. Sorted by stereotype name then `xmi:uuid`.

---

## 24. Canonical XMI B Compliance {#24-canonical-xmi-b-compliance}

This section maps each OMG XMI 2.5.1 Annex B requirement to its implementation in the stylesheet.

### B.2 — Serialisation rules {#b2-serialisation-rules}

| Requirement | Status | Implementation |
|---|---|---|
| B.2.1 — UTF-8 encoding | ✓ Met | `<xsl:output encoding="UTF-8"/>` |
| B.2.2 — Root `xmi:XMI` element | ✓ Met | Always emitted as root |
| B.2.3 — Namespace declarations in usage order | ✓ Met | `xmi`, `uml`, then profile namespaces declared on `xmi:XMI` |
| B.2.4 — Self-closing for reference elements | ✓ Met | `type`, `general`, `memberEnd`, `association`, `client`, `supplier`, `annotatedElement`, `base_XXX` all self-closing |
| B.2.5 — XMI attributes in order: id, uuid, type | ✓ Met | Enforced by `xsl:attribute` instruction order in all templates |
| B.2.6 — `xmi:type` present on all class instances | ✓ Met | Emitted on all output elements including `uml:Model` |
| B.2.7 — `xmi:id` and `xmi:uuid` present on all objects | ✓ Met | Emitted for all class instances |
| B.2.8 — `xsi:nil` never used | ✓ Met | Never emitted |
| B.2.9 — Links as properties, not Link elements | ✓ Met | All references use class properties |
| B.2.10 — `href` only for cross-model references | ✓ Met | Same-file references always use `xmi:idref`; `href` only for standard UML primitives |
| B.2.11 — `xmi:difference`, `xmi:documentation`, `xmi:extension`, `xmi:label` absent | ✓ Met | None ever emitted |
| B.2.12 — Opposite properties both serialised | ✓ Met | `association` child emitted on both `ownedAttribute` and `ownedEnd` |
| B.2.13 — Canonical lexical representation | ✓ Met | Booleans as `true`/`false`; unlimited as `*` |

### B.3 — Identity {#b3-identity}

| Requirement | Status | Implementation |
|---|---|---|
| Deterministic `xmi:id` | ✓ Met | Computed from `prefix.createdName`; prefix from `PackageInformation` per package |
| Deterministic `xmi:uuid` | ✓ Met | Computed from `nsURI#createdName`; URI from package `URI` attribute |
| Per-package prefix scoping | ✓ Met | `resolvePackagePrefix` called at each package level; tunnel parameter propagates to children |
| Cross-package reference resolution | ✓ Met | `computeElementPrefix` walks source document ancestors to find correct prefix for any referenced element |

### B.4 — `xmi:type` {#b4-xmitype}

| Requirement | Status | Implementation |
|---|---|---|
| `xmi:type` on all class instances | ✓ Met | All 13 UCMIS metaclasses emit correct `xmi:type` |
| `xmi:type` absent on reference elements | ✓ Met | Self-closing reference elements carry only `xmi:idref` or `href` |

### B.5 — Element ordering {#b5-element-ordering}

| Requirement | Status | Implementation |
|---|---|---|
| B.5.1 — Top-level elements | ✓ Met | `uml:Model` first; Standard Profile stereotypes after; external profile stereotypes last |
| B.5.1 — `packagedElement` sorted by type then uuid | ✓ Met | `xsl:sort` applied in all `apply-templates` for `packagedElement` |
| B.5.2 — Package/Model property order | ✓ Met | `ownedComment`, `name`, `URI`, `packagedElement` |
| B.5.3 — Association: nested before link elements | ✓ Met | `ownedEnd` emitted before `memberEnd` |
| B.5.4 — Class/DataType property order | ✓ Met | `ownedComment`, `name`, `isAbstract`, `generalization`, `ownedAttribute` |
| B.5.4 — Property (ownedAttribute) property order | ✓ Met | Full 10-property order as specified |

### B.6 — Attribute-to-element conversion {#b6-attribute-to-element-conversion}

| Requirement | Status | Implementation |
|---|---|---|
| All UML properties as child elements | ✓ Met | `name`, `body`, `isAbstract`, `isReadOnly`, `isDerived`, `value`, `aggregation`, `client`, `supplier`, `general` all emitted as child elements |
| Only `xmi:id`, `xmi:uuid`, `xmi:type` as XML attributes | ✓ Met | Enforced in all canonical templates |

### B.7 — Default value suppression {#b7-default-value-suppression}

| Requirement | Status | Implementation |
|---|---|---|
| `lowerValue=1` suppressed | ✓ Met | `emitLowerValue` suppresses value 1 and absent |
| `upperValue=1` suppressed | ✓ Met | `emitUpperValue` suppresses value 1 and absent |
| Boolean defaults suppressed | ✓ Met | `isAbstract`, `isReadOnly`, `isDerived` suppressed when `false` |

### B.8 — Cross-model references {#b8-cross-model-references}

| Requirement | Status | Implementation |
|---|---|---|
| `href` for standard UML primitive types | ✓ Met | Both OMG and Eclipse URIs produced; controlled by `eclipseOutput` |
| Same-file references as `xmi:idref` | ✓ Met | `resolveIdref` always produces `xmi:idref` for same-file elements |
| Primitive type href normalisation | ✓ Met | `canonical-ref` rewrites both Eclipse and OMG input hrefs to the target URI |

### Scope boundary {#scope-boundary}

The following UML metaclasses are **outside the UCMIS scope** and are suppressed with `[WARNING]`: `uml:Interface`, `uml:Component`, `uml:UseCase`, `uml:Actor`, `uml:Signal`, `uml:Reception`, `uml:Operation`, `uml:Parameter`, `uml:Constraint`, `uml:TemplateParameter`, `uml:Realization`, `uml:Usage`, `uml:InformationFlow`, `uml:AssociationClass`, `uml:InstanceSpecification`, `uml:Slot`, and all behavioural metaclasses (state machines, activities, interactions).

---

## 25. Known Limitations {#25-known-limitations}

### L1. `defaultValue` type coverage {#l1-defaultvalue-type-coverage}

Only `uml:LiteralString`, `uml:LiteralInteger`, and `uml:LiteralUnlimitedNatural` value types are explicitly handled. `uml:LiteralBoolean`, `uml:LiteralReal`, `uml:LiteralNull`, and `uml:OpaqueExpression` are passed through if present in the intermediate tree but may not be fully normalised.

### L2. Non-binary associations {#l2-non-binary-associations}

UCMIS restricts to binary directed associations. N-ary associations (more than two `memberEnd` elements) would produce unexpected output. No error or warning is emitted.

### L3. `ownedEnd` type disambiguation fallback {#l3-ownedend-type-disambiguation-fallback}

When an association has multiple `ownedEnd` elements and the type class name cannot be resolved for one of them, the positional fallback (`-1`, `-2`) is used in the `xmi:id`. This is rare in well-formed UCMIS models.

### L4. `PackageInformation` in canonical output {#l4-packageinformation-in-canonical-output}

The `PackageInformation` DataType is present in the canonical output as a regular `uml:DataType`. Consumer tools will see it as an ordinary DataType. Whether this is desirable depends on the consuming application. An option to suppress it has not been implemented.

### L5. Cross-file `href` references not validated {#l5-cross-file-href-references-not-validated}

Cross-model `href` references (other than standard UML primitive types) are passed through unchanged. No validation is performed on whether the referenced element exists.

### L6. `name` element in XSLT source {#l6-name-element-in-xslt-source}

The `emitNameElement` template uses a literal `<n>` element in the XSLT source to avoid collision with the XSLT `name()` function in certain tool contexts. The output element name `name` is correct.

---

## 26. Invocation Reference {#26-invocation-reference}

### Requirements {#requirements}

- Java 11 or later (Java 21 recommended)
- Saxon HE 12

### Stylesheet invocation (Saxon command line) {#stylesheet-invocation-saxon-command-line}

```bash
java -jar saxon-he-12.x.jar \
  -s:input.xmi \
  -xsl:to-canonical-xmi.xslt \
  -o:output.xmi \
  [parameter=value ...]

```

### Common invocation patterns {#common-invocation-patterns}

```bash
# EA input, OMG output, prefix and URI from PackageInformation  
# {#ea-input-omg-output-prefix-and-uri-from-packageinformation}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi

# EA input with explicit prefix and namespace URI  
# {#ea-input-with-explicit-prefix-and-namespace-uri}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  namespacePrefix=LIB "namespaceURI=http://example.org/lib"

# Eclipse input, OMG output {#eclipse-input-omg-output}
java -jar saxon-he-12.x.jar \
  -s:model.uml -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  input=eclipse namespacePrefix=LIB "namespaceURI=http://example.org/lib"

# Eclipse input, Eclipse output namespace {#eclipse-input-eclipse-output-namespace}
java -jar saxon-he-12.x.jar \
  -s:model.uml -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  input=eclipse eclipseOutput=yes \
  namespacePrefix=LIB "namespaceURI=http://example.org/lib"

# EA input with external profile {#ea-input-with-external-profile}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  namespacePrefix=LIB "namespaceURI=http://example.org/lib" \
  profilePrefix=schemaProfile \
  "profileNamespaceURI=http://ucmis.org/profiles/schema/1.0"

# Promote named package to uml:Model root {#promote-named-package-to-umlmodel-root}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  sourcePackageName=MyModel namespacePrefix=LIB

# Preserve source ids (pass-through mode) {#preserve-source-ids-pass-through-mode}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  generateIds=no

# Validate qualified names from source {#validate-qualified-names-from-source}
java -jar saxon-he-12.x.jar \
  -s:model.xmi -xsl:to-canonical-xmi.xslt -o:canonical.xmi \
  sourceHasQualifiedNames=yes namespacePrefix=LIB

```

### Fat JAR invocation {#fat-jar-invocation}

```bash
# Linux/macOS (launcher script) {#linuxmacos-launcher-script}
./to-canonical-xmi.sh -s:model.xmi -o:canonical.xmi namespacePrefix=LIB

# Windows (launcher script) {#windows-launcher-script}
to-canonical-xmi.bat -s:model.xmi -o:canonical.xmi namespacePrefix=LIB

# Direct Java invocation (all platforms) {#direct-java-invocation-all-platforms}
java -jar to-canonical-xmi-1.0.0.jar \
  -s:model.xmi -o:canonical.xmi namespacePrefix=LIB

```

### Maven wrapper invocation {#maven-wrapper-invocation}

```bash
./mvnw.sh exec:java \
  -Dxslt.input=model.xmi \
  -Dxslt.output=canonical.xmi \
  -Dxslt.namespacePrefix=LIB \
  "-Dxslt.namespaceURI=http://example.org/lib"

```

### Parameter quick reference {#parameter-quick-reference}

| Parameter | Default | Values |
|---|---|---|
| `generateIds` | `yes` | `yes` \| `no` |
| `namespaceURI` | *(empty)* | Any URI string |
| `namespacePrefix` | *(empty)* | Any NCName string |
| `qualifiedAssocNames` | `yes` | `yes` \| `no` |
| `sourceHasQualifiedNames` | `no` | `yes` \| `no` |
| `sourcePackageName` | *(empty)* | Package name string |
| `input` | *(auto)* | `ea` \| `eclipse` \| `generic` |
| `eclipseOutput` | `no` | `yes` \| `no` |
| `profilePrefix` | *(empty)* | Namespace prefix string |
| `profileNamespaceURI` | *(empty)* | Any URI string |
