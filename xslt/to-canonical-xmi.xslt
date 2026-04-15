<?xml version="1.0" encoding="UTF-8"?>
<!--
  to-canonical-xmi.xslt
  Transforms Enterprise Architect XMI and Eclipse UML XMI to Canonical XMI
  for UCMIS (UML Class Model Interoperable Subset) UML class models.

  Usage (Saxon-HE):
    java -jar saxon-he.jar \
      -s:input.xmi \
      -xsl:to-canonical-xmi.xslt \
      -o:output-canonical.xmi \
      generateIds=yes \
      namespacePrefix=LIB \
      "namespaceURI=http://example.org/lib"

  Eclipse input with OMG output namespace (default):
    java -jar saxon-he.jar -s:model.uml -xsl:to-canonical-xmi.xslt -o:out.xmi input=eclipse

  Any input with Eclipse output namespace:
    java -jar saxon-he.jar -s:model.xmi -xsl:to-canonical-xmi.xslt -o:out.xmi eclipseOutput=yes

  Eclipse input with Eclipse output namespace:
    java -jar saxon-he.jar -s:model.uml -xsl:to-canonical-xmi.xslt -o:out.xmi input=eclipse eclipseOutput=yes

  Force EA processing mode:
    java -jar saxon-he.jar -s:model.xmi -xsl:to-canonical-xmi.xslt -o:out.xmi input=ea

  Force generic processing mode:
    java -jar saxon-he.jar -s:model.xmi -xsl:to-canonical-xmi.xslt -o:out.xmi input=generic

  External profile stereotypes (prefix discovered from root element):
    java -jar saxon-he.jar -s:model.xmi -xsl:to-canonical-xmi.xslt -o:out.xmi profilePrefix=schemaProfile

  External profile stereotypes with namespace URI override:
    java -jar saxon-he.jar -s:model.xmi -xsl:to-canonical-xmi.xslt -o:out.xmi \
      profilePrefix=schemaProfile "profileNamespaceURI=http://ucmis.org/profiles/schema/1.0"

  See parameter documentation below for all options.
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xd="http://www.pnp-software.com/XSLTdoc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xmi="http://www.omg.org/spec/XMI/20131001"
  xmlns:uml="http://www.omg.org/spec/UML/20131001"
  exclude-result-prefixes="xd xs xmi uml"
  version="2.0">

  <xd:doc type="stylesheet">
    <xd:short>Transforms EA XMI and Eclipse UML XMI to Canonical XMI for UCMIS UML class models.</xd:short>
    <xd:detail>Implements the UCMIS Canonical XMI format (OMG XMI 2.5.1 Annex B) for UML Class
    Model Interoperable Subset (UCMIS) models. Supports single inheritance, binary directed
    associations, uml:Abstraction with Standard Profile stereotypes (Derive, Refine, Trace),
    and external profile stereotype pass-through.

    Input flavours (auto-detected or set via the 'input' parameter):
      ea      — Enterprise Architect XMI (promotes first sub-package to uml:Model)
      eclipse — Eclipse UML2 XMI (handles xmi:XMI-rooted and uml:Model-rooted input)
      generic — minimal pass-through for near-canonical input

    Output namespace (controlled by eclipseOutput parameter):
      no (default) — OMG UML namespace and primitive type URIs
      yes          — Eclipse UML2 namespace and primitive type URIs

    Per-package xmi:id prefix and xmi:uuid namespace URI are resolved from
    PackageInformation DataType children (attributes: prefix, URI) at each package level,
    with inner packages overriding outer ones.

    Parameters: generateIds, namespaceURI, namespacePrefix, qualifiedAssocNames,
    sourceHasQualifiedNames, sourcePackageName, input, eclipseOutput,
    profilePrefix, profileNamespaceURI.

    Version 1.0</xd:detail>
    <xd:author>joachim.wackerow@posteo.de</xd:author>
    <xd:copyright>Joachim Wackerow</xd:copyright>
  </xd:doc>

  <xsl:output
    method="xml"
    encoding="UTF-8"
    indent="yes"
    omit-xml-declaration="no"/>

  <!-- ============================================================
       SECTION 1: PARAMETERS
       ============================================================ -->

  <xd:doc type="string">
    <xd:short>Whether to generate new xmi:id and xmi:uuid values.</xd:short>
    <xd:detail>If 'yes', deterministic ids and uuids are generated based on prefix and name.
    If 'no', source ids are passed through with warnings for invalid characters.</xd:detail>
  </xd:doc>
  <xsl:param name="generateIds" as="xs:string" select="'yes'"/>

  <xd:doc type="string">
    <xd:short>Override namespace URI for all model elements.</xd:short>
    <xd:detail>If empty, the URI is resolved from the nearest enclosing package with a URI attribute,
    or from a PackageInformation DataType with a 'prefix' attribute.</xd:detail>
  </xd:doc>
  <xsl:param name="namespaceURI" as="xs:string" select="''"/>

  <xd:doc type="string">
    <xd:short>Override namespace prefix for all model elements.</xd:short>
    <xd:detail>If empty, the prefix is resolved from a PackageInformation DataType.
    Falls back to the model name with a warning.</xd:detail>
  </xd:doc>
  <xsl:param name="namespacePrefix" as="xs:string" select="''"/>

  <xd:doc type="string">
    <xd:short>Whether to produce qualified association names.</xd:short>
    <xd:detail>If 'yes', association names are qualified as SubjectClass_assocName_ObjectClass.</xd:detail>
  </xd:doc>
  <xsl:param name="qualifiedAssocNames" as="xs:string" select="'yes'"/>

  <xd:doc type="string">
    <xd:short>Whether the source model already has qualified association names.</xd:short>
    <xd:detail>If 'yes', the XSLT re-derives and validates the qualified names, warning on mismatch.</xd:detail>
  </xd:doc>
  <xsl:param name="sourceHasQualifiedNames" as="xs:string" select="'no'"/>

  <xd:doc type="string">
    <xd:short>Name of a specific source package to use as the output uml:Model root.</xd:short>
    <xd:detail>If set, the XSLT searches recursively for a package with this name and promotes it
    to uml:Model. If empty, the normal root resolution applies.</xd:detail>
  </xd:doc>
  <xsl:param name="sourcePackageName" as="xs:string" select="''"/>

  <xd:doc type="string">
    <xd:short>Override the input flavour detection.</xd:short>
    <xd:detail>Accepted values: 'ea', 'eclipse', 'generic'. If empty (default), the input
    flavour is auto-detected: EA input is identified by the presence of an EA extension block,
    Eclipse input by its UML namespace URI, and anything else is treated as generic.
    Use this parameter to force a specific processing path when auto-detection is insufficient.</xd:detail>
  </xd:doc>
  <xsl:param name="input" as="xs:string" select="''"/>

  <xd:doc type="string">
    <xd:short>Whether to use Eclipse-specific UML namespace and primitive type URIs in the output.</xd:short>
    <xd:detail>If 'yes', the output uses xmlns:uml="http://www.eclipse.org/uml2/5.0.0/UML"
    and primitive type hrefs from http://www.eclipse.org/uml2/5.0.0/UML/PrimitiveTypes.xmi.
    If 'no' (default), the OMG UML namespace and primitive type URIs are used.
    Independent of the input parameter — any input flavour can produce either output namespace.</xd:detail>
  </xd:doc>
  <xsl:param name="eclipseOutput" as="xs:string" select="'no'"/>

  <xd:doc type="string">
    <xd:short>Namespace prefix of an external UML profile whose stereotypes should be transformed.</xd:short>
    <xd:detail>If set, stereotype application elements in this namespace prefix are passed through
    to the canonical output as top-level xmi:XMI children, after the StandardProfile elements.
    The namespace URI is discovered from the root element namespace declarations.
    If the URI cannot be discovered and profileNamespaceURI is not set, an error is emitted.
    Example: profilePrefix=schemaProfile</xd:detail>
  </xd:doc>
  <xsl:param name="profilePrefix" as="xs:string" select="''"/>

  <xd:doc type="string">
    <xd:short>Namespace URI override for the external profile specified by profilePrefix.</xd:short>
    <xd:detail>If empty (default), the namespace URI is discovered from the namespace declaration
    for profilePrefix on the root element. If set, this URI overrides the discovered value.
    Has no effect when profilePrefix is empty.</xd:detail>
  </xd:doc>
  <xsl:param name="profileNamespaceURI" as="xs:string" select="''"/>

  <!-- ============================================================
       SECTION 2: GLOBAL CONSTANTS AND DERIVED VARIABLES
       ============================================================ -->

  <xd:doc>
    <xd:short>UML namespace URI for standard (non-Eclipse) output.</xd:short>
  </xd:doc>
  <xsl:variable name="UML_NS" as="xs:string"
    select="'http://www.omg.org/spec/UML/20131001'"/>

  <xd:doc>
    <xd:short>UML namespace URI for Eclipse output.</xd:short>
  </xd:doc>
  <xsl:variable name="UML_NS_ECLIPSE" as="xs:string"
    select="'http://www.eclipse.org/uml2/5.0.0/UML'"/>

  <xd:doc>
    <xd:short>Standard Profile namespace URI for OMG output.</xd:short>
  </xd:doc>
  <xsl:variable name="STDPROFILE_NS" as="xs:string"
    select="'http://www.omg.org/spec/UML/20131001/StandardProfile'"/>

  <xd:doc>
    <xd:short>Standard Profile namespace URI for Eclipse output.</xd:short>
  </xd:doc>
  <xsl:variable name="STDPROFILE_NS_ECLIPSE" as="xs:string"
    select="'http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard'"/>

  <xd:doc>
    <xd:short>The three Standard Profile stereotype names applicable to uml:Abstraction.</xd:short>
  </xd:doc>
  <xsl:variable name="ABSTRACTION_STEREOTYPES" as="xs:string*"
    select="('Derive', 'Refine', 'Trace')"/>

  <xd:doc>
    <xd:short>Resolved namespace URI for the external profile (if profilePrefix is set).</xd:short>
    <xd:detail>When profileNamespaceURI is set, uses that value. Otherwise discovers the URI
    from the namespace declaration for profilePrefix on the root element using
    namespace-uri-for-prefix(). If neither source is available and profilePrefix is set,
    an error is emitted and an empty string is returned (causing subsequent output to be
    suppressed).</xd:detail>
  </xd:doc>
  <xsl:variable name="effectiveProfileNsURI" as="xs:string">
    <xsl:choose>
      <xsl:when test="$profilePrefix = ''">
        <xsl:value-of select="''"/>
      </xsl:when>
      <xsl:when test="$profileNamespaceURI != ''">
        <xsl:value-of select="$profileNamespaceURI"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Discover from root element namespace declarations -->
        <xsl:variable name="rootNs"
          select="namespace-uri-for-prefix($profilePrefix, (/*)[1])"/>
        <xsl:choose>
          <xsl:when test="$rootNs != ''">
            <xsl:value-of select="$rootNs"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>[ERROR] Cannot find namespace URI for profile prefix '<xsl:value-of
              select="$profilePrefix"/>'. Declare it on the root element or supply profileNamespaceURI parameter.</xsl:message>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xd:doc>
    <xd:short>XMI namespace URI.</xd:short>
  </xd:doc>
  <xsl:variable name="XMI_NS" as="xs:string"
    select="'http://www.omg.org/spec/XMI/20131001'"/>

  <xd:doc>
    <xd:short>UML primitive types base URI for standard output.</xd:short>
  </xd:doc>
  <xsl:variable name="UML_PRIMITIVES_BASE" as="xs:string"
    select="if ($eclipseOutput = 'yes')
            then 'http://www.eclipse.org/uml2/5.0.0/UML/PrimitiveTypes.xmi#'
            else 'http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#'"/>

  <xd:doc>
    <xd:short>Inline lookup table mapping EA/tool primitive type names to canonical UML primitive names.</xd:short>
  </xd:doc>
  <xsl:variable name="primitiveTypeMap">
    <entry ea="Integer"          uml="Integer"/>
    <entry ea="int"              uml="Integer"/>
    <entry ea="String"           uml="String"/>
    <entry ea="string"           uml="String"/>
    <entry ea="Boolean"          uml="Boolean"/>
    <entry ea="boolean"          uml="Boolean"/>
    <entry ea="Real"             uml="Real"/>
    <entry ea="Double"           uml="Real"/>
    <entry ea="double"           uml="Real"/>
    <entry ea="Float"            uml="Real"/>
    <entry ea="float"            uml="Real"/>
    <entry ea="UnlimitedNatural" uml="UnlimitedNatural"/>
  </xsl:variable>

  <xd:doc>
    <xd:short>Inline lookup table mapping XML element names to xmi:type values for Eclipse inference.</xd:short>
  </xd:doc>
  <xsl:variable name="elementTypeMap">
    <entry elem="ownedAttribute"    type="uml:Property"/>
    <entry elem="ownedEnd"          type="uml:Property"/>
    <entry elem="generalization"    type="uml:Generalization"/>
    <entry elem="ownedLiteral"      type="uml:EnumerationLiteral"/>
    <entry elem="ownedComment"      type="uml:Comment"/>
    <entry elem="lowerValue"        type="uml:LiteralInteger"/>
    <entry elem="upperValue"        type="uml:LiteralUnlimitedNatural"/>
    <entry elem="defaultValue"      type="uml:LiteralString"/>
    <entry elem="packagedElement"   type="uml:Class"/>
  </xsl:variable>

  <xd:doc>
    <xd:short>Detected input flavour: 'ea', 'eclipse', or 'generic'.</xd:short>
    <xd:detail>Auto-detected from presence of EA extension block or Eclipse UML namespace.
    The eclipse parameter overrides to 'eclipse'.</xd:detail>
  </xd:doc>
  <xsl:variable name="inputFlavour" as="xs:string">
    <xsl:choose>
      <!-- Explicit override via 'input' parameter takes priority -->
      <xsl:when test="$input = 'ea'">ea</xsl:when>
      <xsl:when test="$input = 'eclipse'">eclipse</xsl:when>
      <xsl:when test="$input = 'generic'">generic</xsl:when>
      <!-- Auto-detection when input parameter is empty -->
      <xsl:when test="/xmi:XMI/xmi:Extension[@extender='Enterprise Architect']
                      or /xmi:XMI/xmi:Documentation[@exporter='Enterprise Architect']">ea</xsl:when>
      <xsl:when test="namespace-uri(/*) = $UML_NS_ECLIPSE
                      or /xmi:XMI/*[local-name()='Model'][namespace-uri() = $UML_NS_ECLIPSE]">eclipse</xsl:when>
      <xsl:otherwise>generic</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- ============================================================
       MODE DOCUMENTATION (for XSLTdoc Template Modes Summary)
       ============================================================ -->

  <xd:doc mode="#default">
    <xd:short>Entry point: builds the intermediate tree and drives the canonical pass.</xd:short>
    <xd:detail>
      The match="/" template detects the input flavour, builds the EA extension
      tree (EA input only), runs the appropriate preprocess mode to produce a flavour-neutral
      intermediate tree, then applies the canonical mode to produce the final Canonical XMI
      output.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="canonical">
    <xd:short>Transforms the intermediate tree into Canonical XMI output.</xd:short>
    <xd:detail>
      Enforces canonical property ordering, attribute-to-element conversion,
      multiplicity default suppression, deterministic xmi:id and xmi:uuid generation,
      and per-package prefix and namespace URI resolution from PackageInformation DataType
      children. Emits the final xmi:XMI document including uml:Model, Standard Profile
      stereotype applications (Derive, Refine, Trace), and external profile stereotype
      applications.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="canonical-comment">
    <xd:short>Emits a uml:Comment element in canonical form.</xd:short>
    <xd:detail>
      Handles ownedComment elements, converting body text and annotatedElement
      references to canonical child element form. Called from all canonical templates
      that may carry associated documentation comments.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="canonical-ref">
    <xd:short>Resolves type, general, and association reference elements to canonical form.</xd:short>
    <xd:detail>
      Handles elements carrying xmi:idref (same-file references) or href
      (cross-file or primitive type references). Normalises primitive type hrefs to match
      the target namespace selected by eclipseOutput. Resolves same-file idrefs to their
      canonical xmi:id values via resolveIdref.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="canonical-value">
    <xd:short>Emits lowerValue, upperValue, and defaultValue elements in canonical form.</xd:short>
    <xd:detail>
      Suppresses multiplicity elements whose values match the UML default
      (lowerValue=1, upperValue=1). Handles LiteralInteger, LiteralUnlimitedNatural,
      and LiteralString value types.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="ea-preprocess">
    <xd:short>Transforms Enterprise Architect XMI into the flavour-neutral intermediate tree.</xd:short>
    <xd:detail>
      Strips EA-specific wrapper elements, promotes the selected root package to
      uml:Model, injects ownedComment from the EA extension documentation tree, resolves
      EA primitive type idrefs to canonical UML hrefs, injects _stereotype synthetic elements
      for Standard Profile Abstractions, and collects external profile stereotype
      applications. The extension tree is passed as a tunnel parameter throughout.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="ea-preprocess-as-model">
    <xd:short>Renders the selected EA root package as the intermediate uml:Model element.</xd:short>
    <xd:detail>
      Called once from the EA preprocess root template on the package selected
      as the output uml:Model root (first sub-package or the package named by
      sourcePackageName). Injects ownedComment from the extension tree and recurses into
      child elements via ea-preprocess mode.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="eclipse-preprocess">
    <xd:short>Transforms Eclipse UML2 XMI into the flavour-neutral intermediate tree.</xd:short>
    <xd:detail>
      Handles xmi:XMI-rooted and uml:Model-rooted Eclipse input. Infers missing
      xmi:type from element names, converts space-separated memberEnd attributes to child
      memberEnd elements for Associations, passes Standard Profile stereotype applications
      through as _stereotypeApplication synthetic elements, and collects external profile
      stereotype applications. Suppresses non-UML namespace elements except Standard Profile
      and external profile namespaces.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="eclipse-preprocess-as-model">
    <xd:short>Renders the Eclipse uml:Model or promoted package as the intermediate root.</xd:short>
    <xd:detail>
      Called from the Eclipse preprocess root template. Handles optional
      sourcePackageName promotion, then recurses into child elements via
      eclipse-preprocess mode.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="generic-copy">
    <xd:short>Minimal pass-through for near-canonical or unknown input.</xd:short>
    <xd:detail>
      Filters elements to UML and no-namespace only, copies xmi:id, xmi:uuid,
      xmi:type, and all other attributes unchanged, and recurses into children. Used when
      input=generic is set or when the input cannot be identified as EA or Eclipse.
    </xd:detail>
  </xd:doc>

  <xd:doc mode="generic-preprocess">
    <xd:short>Entry point for the generic input flavour processing path.</xd:short>
    <xd:detail>
      Minimal preprocessing for input that is neither EA nor Eclipse.
      Applies generic-copy mode to document root children, producing an intermediate
      tree with minimal transformation.
    </xd:detail>
  </xd:doc>

  <!-- ============================================================
       SECTION 3: XSL:KEY DECLARATIONS
       ============================================================ -->

  <xd:doc>
    <xd:short>Key: all source elements by xmi:id.</xd:short>
  </xd:doc>
  <xsl:key name="elementById" match="*[@xmi:id]" use="@xmi:id"/>

  <xd:doc>
    <xd:short>Key: Association packagedElements by xmi:id.</xd:short>
  </xd:doc>
  <xsl:key name="assocById"
    match="packagedElement[@xmi:type='uml:Association']
           | *[@xmi:type='uml:Association']"
    use="@xmi:id"/>

  <xd:doc>
    <xd:short>Key: PrimitiveType elements by xmi:id in source document.</xd:short>
  </xd:doc>
  <!-- Matches only EA built-in primitive types (id starts with 'EAJava_' or
       element is nested inside an EA primitive types package).
       User-defined PrimitiveType elements in the model are NOT matched here;
       they are kept as same-file xmi:idref references. -->
  <xsl:key name="eaBuiltinPrimitiveById"
    match="packagedElement[@xmi:type='uml:PrimitiveType']
                          [starts-with(@xmi:id,'EAJava_')
                           or ancestor::*[starts-with(@xmi:id,'EAPrimitiveTypesPackage')]
                           or ancestor::*[starts-with(@xmi:id,'EAJavaTypesPackage')]]
           | *[@xmi:type='uml:PrimitiveType']
                          [starts-with(@xmi:id,'EAJava_')
                           or ancestor::*[starts-with(@xmi:id,'EAPrimitiveTypesPackage')]
                           or ancestor::*[starts-with(@xmi:id,'EAJavaTypesPackage')]]"
    use="@xmi:id"/>

  
  <xd:doc>
    <xd:short>Key: elements in the intermediate tree by xmi:id (used with 3-arg key() on intermediate tree).</xd:short>
  </xd:doc>
  <xsl:key name="interById" match="*[@xmi:id]" use="@xmi:id"/>

<!-- Keys on temporary extension tree — used with key('name', value, $extTree) -->

  <xd:doc>
    <xd:short>Key: EA extension element records by xmi:idref (for use with temporary tree).</xd:short>
  </xd:doc>
  <xsl:key name="extElementByIdref" match="elementDoc" use="@idref"/>

  <xd:doc>
    <xd:short>Key: EA extension connector records by xmi:idref (for use with temporary tree).</xd:short>
  </xd:doc>
  <xsl:key name="extConnectorByIdref" match="connectorDoc" use="@idref"/>

  <xd:doc>
    <xd:short>Key: EA stereotype records by xmi:idref (for use with temporary tree).</xd:short>
  </xd:doc>
  <xsl:key name="extStereotypeByIdref" match="stereotypeDoc" use="@idref"/>

  <!-- ============================================================
       SECTION 4: ROOT / ENTRY-POINT TEMPLATE
       ============================================================ -->

  <xd:doc>
    <xd:short>Root template: detects input flavour, runs preprocess pass, then canonical pass.</xd:short>
  </xd:doc>
  <xsl:template match="/">

    <!-- Warn on unrecognised input parameter value -->
    <xsl:if test="$input != '' and not($input = ('ea', 'eclipse', 'generic'))">
      <xsl:message>[WARNING] Unrecognised value for parameter 'input': '<xsl:value-of select="$input"/>'. Valid values: ea, eclipse, generic. Falling back to auto-detection.</xsl:message>
    </xsl:if>
    <!-- Warn on generic flavour (auto-detected or forced) -->
    <xsl:if test="$inputFlavour = 'generic'">
      <xsl:message>[WARNING] Input flavour not recognised as EA or Eclipse. Proceeding with generic conversion.</xsl:message>
    </xsl:if>

    <!-- Warn and drop xmi:version if present on xmi:XMI -->
    <xsl:if test="/xmi:XMI/@xmi:version">
      <xsl:message>[WARNING] xmi:version attribute found on xmi:XMI and will be dropped.</xsl:message>
    </xsl:if>

    <!-- Warn on duplicate xmi:id values in source when generateIds=no -->
    <xsl:if test="$generateIds = 'no'">
      <xsl:call-template name="checkDuplicateIds"/>
    </xsl:if>

    <!-- Build extension tree (EA only) -->
    <xsl:variable name="extTree">
      <xsl:if test="$inputFlavour = 'ea'">
        <xsl:call-template name="buildExtensionTree"/>
      </xsl:if>
    </xsl:variable>

    <!-- Run preprocess pass to produce neutral intermediate tree -->
    <xsl:variable name="intermediateTree">
      <xsl:choose>
        <xsl:when test="$inputFlavour = 'ea'">
          <xsl:apply-templates select="." mode="ea-preprocess">
            <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="$inputFlavour = 'eclipse'">
          <xsl:apply-templates select="." mode="eclipse-preprocess"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="generic-preprocess"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <!-- Resolve namespace prefix and URI from intermediate tree -->
    <xsl:variable name="resolvedModel" select="$intermediateTree/uml:Model"/>
    <xsl:variable name="effectiveNsURI" as="xs:string">
      <xsl:call-template name="resolveNamespaceURI">
        <xsl:with-param name="modelNode" select="$resolvedModel"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="effectivePrefix" as="xs:string">
      <xsl:call-template name="resolveNamespacePrefix">
        <xsl:with-param name="modelNode" select="$resolvedModel"/>
        <xsl:with-param name="nsURI" select="$effectiveNsURI"/>
      </xsl:call-template>
    </xsl:variable>

    <!-- Capture source document root for key() lookups in canonical pass -->
    <xsl:variable name="sourceRoot" select="/"/>

    <!-- Run canonical pass on intermediate tree -->
    <xsl:apply-templates select="$intermediateTree" mode="canonical">
      <xsl:with-param name="nsURI"            select="$effectiveNsURI"       tunnel="yes"/>
      <xsl:with-param name="prefix"           select="$effectivePrefix"      tunnel="yes"/>
      <xsl:with-param name="extTree"          select="$extTree"              tunnel="yes"/>
      <xsl:with-param name="intermediateRoot" select="$intermediateTree/*[1]" tunnel="yes"/>
      <xsl:with-param name="sourceRoot"       select="$sourceRoot"           tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- ============================================================
       SECTION 5: EA EXTENSION TREE BUILDER
       ============================================================ -->

  <xd:doc>
    <xd:short>Builds a flat temporary tree of documentation records from the EA extension block.</xd:short>
    <xd:detail>Produces elementDoc records (from elements/element/properties/@documentation)
    and connectorDoc records (from connectors/connector/documentation/@value).
    Keys extElementByIdref and extConnectorByIdref operate on this tree.</xd:detail>
  </xd:doc>
  <xsl:template name="buildExtensionTree">
    <extensionData>
      <!-- Element documentation records -->
      <xsl:for-each select="/xmi:XMI/xmi:Extension/elements/element">
        <xsl:variable name="doc" select="properties/@documentation"/>
        <xsl:if test="normalize-space($doc) != ''">
          <elementDoc idref="{@xmi:idref}" documentation="{$doc}"/>
        </xsl:if>
      </xsl:for-each>
      <!-- Connector documentation records -->
      <xsl:for-each select="/xmi:XMI/xmi:Extension/connectors/connector">
        <xsl:variable name="doc" select="documentation/@value"/>
        <xsl:if test="normalize-space($doc) != ''">
          <connectorDoc idref="{@xmi:idref}" documentation="{$doc}"/>
        </xsl:if>
      </xsl:for-each>
      <!-- Stereotype records for uml:Abstraction connectors with Standard Profile stereotypes.
           Two EA serialisation patterns are handled:
           (a) xmi:Extension/connectors/connector with properties/@stereotype
           (b) Top-level xmi:XMI child in the EAUML namespace: <EAUML:trace base_Dependency="id"/>
               The local-name() gives the stereotype name (lowercase); we capitalise it. -->
      <xsl:for-each select="/xmi:XMI/xmi:Extension/connectors/connector
                              [properties/@ea_type='Abstraction']
                              [properties/@stereotype = ('Derive','Refine','Trace')]">
        <stereotypeDoc idref="{@xmi:idref}"
                       stereotype="{properties/@stereotype}"/>
      </xsl:for-each>
      <!-- Pattern (b): top-level elements in the Sparx EAUML namespace only.
           EAUML:trace/derive/refine elements use base_Dependency to reference
           the Abstraction id. Restricted to the EAUML namespace so that
           StandardProfileL2:Refine, thecustomprofile:Refine, and other
           third-party profile elements are NOT matched here — their ids are
           all covered by pattern (a) connector records. -->
      <xsl:variable name="eaumlNS"
        select="'http://www.sparxsystems.com/profiles/EAUML/1.0'"/>
      <xsl:variable name="patternAIds"
        select="/xmi:XMI/xmi:Extension/connectors/connector
                  [properties/@ea_type='Abstraction']
                  [properties/@stereotype = ('Derive','Refine','Trace')]/@xmi:idref"/>
      <xsl:for-each select="/xmi:XMI/*[namespace-uri() = $eaumlNS]
                                      [lower-case(local-name()) = ('trace','derive','refine')]
                                      [@base_Dependency or @base_Abstraction]">
        <xsl:variable name="stereoId"
          select="string((@base_Dependency, @base_Abstraction)[1])"/>
        <xsl:variable name="stereoName"
          select="concat(upper-case(substring(local-name(),1,1)),
                         substring(local-name(),2))"/>
        <!-- Skip if pattern (a) already produced a record for this id -->
        <xsl:if test="not($stereoId = $patternAIds)">
          <stereotypeDoc idref="{$stereoId}" stereotype="{$stereoName}"/>
        </xsl:if>
      </xsl:for-each>
    </extensionData>
  </xsl:template>

  <!-- ============================================================
       SECTION 6: EA PREPROCESS MODE
       ============================================================ -->

  <xd:doc>
    <xd:short>EA preprocess root: promotes the first sub-package (or sourcePackageName) to uml:Model.</xd:short>
  </xd:doc>
  <xsl:template match="/" mode="ea-preprocess">
    <xsl:param name="extTree" tunnel="yes"/>
    <!-- Find the target root package -->
    <xsl:variable name="rootPackage" as="element()?">
      <xsl:choose>
        <xsl:when test="$sourcePackageName != ''">
          <xsl:sequence select="(//packagedElement[@xmi:type='uml:Package']
                                  [not(ancestor::xmi:Extension)]
                                  [@name = $sourcePackageName])[1]"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- First packagedElement under EA wrapper uml:Model -->
          <xsl:sequence select="(xmi:XMI/uml:Model/packagedElement[@xmi:type='uml:Package'])[1]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="empty($rootPackage)">
      <xsl:message terminate="yes">[ERROR] Cannot find root package. Check sourcePackageName parameter.</xsl:message>
    </xsl:if>
    <xsl:apply-templates select="$rootPackage" mode="ea-preprocess-as-model"/>
    <!-- Collect external profile stereotype applications from top-level xmi:XMI children.
         Match by PREFIX (local-name of the namespace node) not by URI, because the source
         namespace URI may differ from the profileNamespaceURI override parameter. -->
    <xsl:if test="$profilePrefix != ''">
      <xsl:variable name="sourceProfileNs"
        select="namespace-uri-for-prefix($profilePrefix, xmi:XMI)"/>
      <xsl:for-each select="xmi:XMI/*[namespace-uri() = $sourceProfileNs]">
        <xsl:call-template name="normaliseExternalStereoApp"/>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xd:doc>
    <xd:short>Renders the selected EA package as a uml:Model element in the neutral intermediate tree.</xd:short>
  </xd:doc>
  <xsl:template match="packagedElement[@xmi:type='uml:Package']" mode="ea-preprocess-as-model">
    <xsl:param name="extTree" tunnel="yes"/>
    <uml:Model xmi:id="{@xmi:id}">
      <xsl:if test="@xmi:uuid"><xsl:attribute name="xmi:uuid" select="@xmi:uuid"/></xsl:if>
      <xsl:if test="@URI"><xsl:attribute name="URI" select="@URI"/></xsl:if>
      <xsl:attribute name="name" select="@name"/>
      <!-- Inject ownedComment if documentation exists -->
      <xsl:call-template name="ea-injectComment">
        <xsl:with-param name="idref" select="@xmi:id"/>
        <xsl:with-param name="extTree" select="$extTree"/>
      </xsl:call-template>
      <!-- Process children, suppressing EA-specific content -->
      <xsl:apply-templates select="packagedElement | ownedComment" mode="ea-preprocess">
        <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
      </xsl:apply-templates>
    </uml:Model>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for packagedElement of all recognised UML types.</xd:short>
  </xd:doc>
  <xsl:template match="packagedElement[not(@xmi:type='uml:Package' and @xmi:id = (
                          /xmi:XMI/xmi:Extension/primitivetypes//packagedElement/@xmi:id,
                          'EAPrimitiveTypesPackage', 'EAJavaTypesPackage'))]"
                mode="ea-preprocess">
    <xsl:param name="extTree" tunnel="yes"/>
    <xsl:variable name="type" select="@xmi:type"/>
    <xsl:choose>
      <!-- Suppress EA internal primitive type packages -->
      <xsl:when test="$type='uml:Package' and (
                        starts-with(@xmi:id,'EAPrimitiveTypesPackage') or
                        starts-with(@xmi:id,'EAJavaTypesPackage') or
                        @name='EA_PrimitiveTypes_Package' or
                        @name='EA_Java_Types_Package')">
        <!-- silently suppress -->
      </xsl:when>
      <!-- Suppress unrecognised types with warning -->
      <xsl:when test="$type != '' and not($type = (
                        'uml:Class','uml:DataType','uml:Enumeration',
                        'uml:PrimitiveType','uml:Association','uml:Dependency',
                        'uml:Abstraction','uml:Package'))">
        <xsl:message>[WARNING] Unrecognised packagedElement type '<xsl:value-of select="$type"/>' — suppressing element '<xsl:value-of select="@name"/>'.</xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <packagedElement>
          <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
          <xsl:if test="@URI"><xsl:attribute name="URI" select="@URI"/></xsl:if>
          <!-- Convert all non-XMI attributes to child elements (handled in canonical pass) -->
          <!-- Store remaining source attributes for canonical pass to pick up -->
          <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type','URI'))]"/>
          <!-- Inject ownedComment -->
          <xsl:variable name="docNode" select="key('extElementByIdref', @xmi:id, $extTree)"/>
          <xsl:variable name="connDoc" select="key('extConnectorByIdref', @xmi:id, $extTree)"/>
          <xsl:variable name="docText" select="($docNode/@documentation, $connDoc/@documentation)[normalize-space(.) != ''][1]"/>
          <xsl:if test="$docText">
            <ownedComment xmi:type="uml:Comment" _annotatedElementId="{@xmi:id}">
              <xsl:attribute name="_body" select="$docText"/>
            </ownedComment>
          </xsl:if>
          <!-- Inject _stereotype element for uml:Abstraction with Standard Profile stereotype -->
          <xsl:if test="$type = 'uml:Abstraction'">
            <xsl:variable name="stereoDoc"
              select="key('extStereotypeByIdref', @xmi:id, $extTree)[1]"/>
            <xsl:if test="$stereoDoc">
              <_stereotype name="{$stereoDoc/@stereotype}"/>
            </xsl:if>
          </xsl:if>
          <!-- Recurse into children -->
          <xsl:apply-templates select="*" mode="ea-preprocess">
            <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
          </xsl:apply-templates>
        </packagedElement>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: nested Package becomes nested packagedElement with uml:Package type.</xd:short>
  </xd:doc>
  <xsl:template match="packagedElement[@xmi:type='uml:Package']" mode="ea-preprocess" priority="5">
    <xsl:param name="extTree" tunnel="yes"/>
    <xsl:if test="not(starts-with(@xmi:id,'EAPrimitiveTypesPackage') or
                      starts-with(@xmi:id,'EAJavaTypesPackage') or
                      @name='EA_PrimitiveTypes_Package' or
                      @name='EA_Java_Types_Package')">
      <packagedElement xmi:type="uml:Package">
        <xsl:copy-of select="@xmi:id | @xmi:uuid"/>
        <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type','URI'))]"/>
        <xsl:if test="@URI"><xsl:attribute name="URI" select="@URI"/></xsl:if>
        <xsl:call-template name="ea-injectComment">
          <xsl:with-param name="idref" select="@xmi:id"/>
          <xsl:with-param name="extTree" select="$extTree"/>
        </xsl:call-template>
        <xsl:apply-templates select="packagedElement | ownedComment" mode="ea-preprocess">
          <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
        </xsl:apply-templates>
      </packagedElement>
    </xsl:if>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for ownedAttribute (class attribute or association end).</xd:short>
  </xd:doc>
  <xsl:template match="ownedAttribute" mode="ea-preprocess">
    <xsl:param name="extTree" tunnel="yes"/>
    <ownedAttribute>
      <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
      <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]"/>
      <!-- Inject comment if any -->
      <xsl:call-template name="ea-injectComment">
        <xsl:with-param name="idref" select="@xmi:id"/>
        <xsl:with-param name="extTree" select="$extTree"/>
      </xsl:call-template>
      <xsl:apply-templates select="*" mode="ea-preprocess">
        <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
      </xsl:apply-templates>
    </ownedAttribute>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for ownedEnd.</xd:short>
  </xd:doc>
  <xsl:template match="ownedEnd" mode="ea-preprocess">
    <xsl:param name="extTree" tunnel="yes"/>
    <ownedEnd>
      <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
      <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]"/>
      <xsl:apply-templates select="*" mode="ea-preprocess">
        <xsl:with-param name="extTree" select="$extTree" tunnel="yes"/>
      </xsl:apply-templates>
    </ownedEnd>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for generalization.</xd:short>
  </xd:doc>
  <xsl:template match="generalization" mode="ea-preprocess">
    <generalization>
      <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
      <!-- Convert @general attribute to child element -->
      <xsl:if test="@general">
        <general xmi:idref="{@general}"/>
      </xsl:if>
      <!-- Also handle any existing general child elements -->
      <xsl:apply-templates select="general | ownedComment" mode="ea-preprocess"/>
    </generalization>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for memberEnd.</xd:short>
  </xd:doc>
  <xsl:template match="memberEnd" mode="ea-preprocess">
    <memberEnd xmi:idref="{@xmi:idref}"/>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for lowerValue and upperValue.</xd:short>
  </xd:doc>
  <xsl:template match="lowerValue | upperValue | defaultValue" mode="ea-preprocess">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
      <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]"/>
      <xsl:apply-templates select="*" mode="ea-preprocess"/>
    </xsl:element>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for type reference (xmi:idref or href).</xd:short>
    <xd:detail>Resolves EA primitive type idrefs to canonical UML href references.</xd:detail>
  </xd:doc>
  <xsl:template match="type" mode="ea-preprocess">
    <xsl:choose>
      <!-- EA primitive type reference -->
      <!-- Only EA built-in primitives (EAJava_*) become href references;
           user-defined PrimitiveTypes remain as same-file xmi:idref -->
      <xsl:when test="@xmi:idref and key('eaBuiltinPrimitiveById', @xmi:idref)">
        <xsl:variable name="ptName" select="key('eaBuiltinPrimitiveById', @xmi:idref)/@name"/>
        <xsl:variable name="canonicalName">
          <xsl:call-template name="resolvePrimitiveType">
            <xsl:with-param name="name" select="$ptName"/>
          </xsl:call-template>
        </xsl:variable>
        <type href="{$UML_PRIMITIVES_BASE}{$canonicalName}"/>
      </xsl:when>
      <!-- Already an href (cross-model) -->
      <xsl:when test="@href">
        <type href="{@href}"/>
      </xsl:when>
      <!-- Same-file idref -->
      <xsl:when test="@xmi:idref">
        <type xmi:idref="{@xmi:idref}"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for general reference in generalization.</xd:short>
  </xd:doc>
  <xsl:template match="general" mode="ea-preprocess">
    <xsl:choose>
      <xsl:when test="@href">
        <general href="{@href}"/>
      </xsl:when>
      <xsl:when test="@xmi:idref">
        <general xmi:idref="{@xmi:idref}"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: pass-through for ownedLiteral (EnumerationLiteral).</xd:short>
  </xd:doc>
  <xsl:template match="ownedLiteral" mode="ea-preprocess">
    <xsl:param name="extTree" tunnel="yes"/>
    <ownedLiteral>
      <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
      <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]"/>
      <xsl:call-template name="ea-injectComment">
        <xsl:with-param name="idref" select="@xmi:id"/>
        <xsl:with-param name="extTree" select="$extTree"/>
      </xsl:call-template>
      <xsl:apply-templates select="*" mode="ea-preprocess"/>
    </ownedLiteral>
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: suppress xmi:Extension, xmi:Documentation, umldi:*, dc:* and diagram elements.</xd:short>
  </xd:doc>
  <xsl:template match="xmi:Extension | xmi:Documentation
                        | *[namespace-uri() = 'http://www.omg.org/spec/UML/20131001/UMLDI']
                        | *[namespace-uri() = 'http://www.omg.org/spec/UML/20131001/UMLDC']
                        | umldi:* | dc:*"
                mode="ea-preprocess" xmlns:umldi="http://www.omg.org/spec/UML/20131001/UMLDI"
                                     xmlns:dc="http://www.omg.org/spec/UML/20131001/UMLDC">
    <!-- silently suppress -->
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: suppress uml:Model wrapper (EA_Model) — process children only.</xd:short>
  </xd:doc>
  <xsl:template match="uml:Model[@name='EA_Model']" mode="ea-preprocess">
    <!-- Do not output the EA wrapper model — handled by root template -->
  </xsl:template>

  <xd:doc>
    <xd:short>EA preprocess: default suppress for unmatched elements.</xd:short>
  </xd:doc>
  <xsl:template match="*" mode="ea-preprocess" priority="-10">
    <!-- Suppress anything not explicitly handled -->
  </xsl:template>

  <!-- Helper: inject ownedComment from extension tree -->
  <xd:doc>
    <xd:short>Injects an ownedComment element from extension documentation if non-empty.</xd:short>
    <xd:param name="idref" type="xs:string">The xmi:id of the owning element.</xd:param>
    <xd:param name="extTree" type="node()">The extension data temporary tree.</xd:param>
  </xd:doc>
  <xsl:template name="ea-injectComment">
    <xsl:param name="idref" as="xs:string"/>
    <xsl:param name="extTree"/>
    <xsl:variable name="elemDoc" select="key('extElementByIdref', $idref, $extTree)/@documentation"/>
    <xsl:variable name="connDoc" select="key('extConnectorByIdref', $idref, $extTree)/@documentation"/>
    <xsl:variable name="doc" select="($elemDoc[normalize-space(.)!=''], $connDoc[normalize-space(.)!=''])[1]"/>
    <xsl:if test="$doc">
      <ownedComment xmi:type="uml:Comment" _annotatedElementId="{$idref}" _body="{$doc}"/>
    </xsl:if>
  </xsl:template>

  <!-- ============================================================
       SECTION 7: ECLIPSE PREPROCESS MODE
       ============================================================ -->

  <xd:doc>
    <xd:short>Eclipse preprocess root: handles both xmi:XMI-rooted and uml:Model-rooted input.</xd:short>
  </xd:doc>
  <xsl:template match="/" mode="eclipse-preprocess">
    <!-- Use local-name() tests to handle both OMG and Eclipse UML namespaces -->
    <xsl:choose>
      <xsl:when test="*[local-name()='XMI']">
        <xsl:variable name="xmiRoot" select="*[local-name()='XMI']"/>
        <xsl:variable name="model"   select="($xmiRoot/*[local-name()='Model'])[1]"/>
        <xsl:if test="count($xmiRoot/*[local-name()='Model']) &gt; 1">
          <xsl:message>[WARNING] Multiple uml:Model elements found in Eclipse xmi:XMI root — using first.</xsl:message>
        </xsl:if>
        <xsl:apply-templates select="$model" mode="eclipse-preprocess-as-model"/>
        <!-- Standard Profile stereotype application elements -->
        <xsl:apply-templates
          select="$xmiRoot/*[namespace-uri() = 'http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard']
                            [local-name() = ('Derive','Refine','Trace')]"
          mode="eclipse-preprocess"/>
        <!-- External profile stereotype application elements -->
        <xsl:if test="$profilePrefix != '' and $effectiveProfileNsURI != ''">
          <xsl:for-each select="$xmiRoot/*[namespace-uri() = $effectiveProfileNsURI]">
            <xsl:call-template name="normaliseExternalStereoApp"/>
          </xsl:for-each>
        </xsl:if>
      </xsl:when>
      <xsl:when test="*[local-name()='Model']">
        <xsl:apply-templates select="*[local-name()='Model']"
          mode="eclipse-preprocess-as-model"/>
        <!-- Standard Profile stereotype application elements -->
        <xsl:apply-templates
          select="*[namespace-uri() = 'http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard']
                   [local-name() = ('Derive','Refine','Trace')]"
          mode="eclipse-preprocess"/>
        <!-- External profile stereotype application elements -->
        <xsl:if test="$profilePrefix != '' and $effectiveProfileNsURI != ''">
          <xsl:for-each select="*[namespace-uri() = $effectiveProfileNsURI]">
            <xsl:call-template name="normaliseExternalStereoApp"/>
          </xsl:for-each>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">[ERROR] Cannot find uml:Model in Eclipse input.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Eclipse preprocess: render uml:Model (or promoted package) as neutral uml:Model.</xd:short>
  </xd:doc>
  <xsl:template match="*[local-name()='Model'] | packagedElement[@xmi:type='uml:Package']"
                mode="eclipse-preprocess-as-model">
    <xsl:variable name="targetNode" as="element()">
      <xsl:choose>
        <xsl:when test="$sourcePackageName != ''">
          <xsl:variable name="found" select="(//packagedElement[@xmi:type='uml:Package']
                                               [@name = $sourcePackageName])[1]"/>
          <xsl:choose>
            <xsl:when test="$found"><xsl:sequence select="$found"/></xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">[ERROR] Cannot find package '<xsl:value-of select="$sourcePackageName"/>' in Eclipse input.</xsl:message>
              <xsl:sequence select="."/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="."/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <uml:Model xmi:id="{$targetNode/@xmi:id}">
      <xsl:if test="$targetNode/@xmi:uuid">
        <xsl:attribute name="xmi:uuid" select="$targetNode/@xmi:uuid"/>
      </xsl:if>
      <xsl:if test="$targetNode/@URI">
        <xsl:attribute name="URI" select="$targetNode/@URI"/>
      </xsl:if>
      <xsl:attribute name="name" select="$targetNode/@name"/>
      <xsl:apply-templates select="$targetNode/*" mode="eclipse-preprocess"/>
    </uml:Model>
  </xsl:template>

  <xd:doc>
    <xd:short>Eclipse preprocess: Association — converts space-separated @memberEnd attribute to child elements.</xd:short>
    <xd:detail>In Eclipse XMI, memberEnd is serialized as a space-separated XML attribute
    (e.g. memberEnd="id1 id2") rather than child elements. This template normalises it
    to child memberEnd elements so the intermediate tree is uniform with EA input.</xd:detail>
  </xd:doc>
  <xsl:template match="*[@xmi:type='uml:Association']" mode="eclipse-preprocess">
    <xsl:variable name="elemName" select="local-name()"/>
    <xsl:element name="{$elemName}">
      <xsl:copy-of select="@xmi:id"/>
      <xsl:if test="@xmi:uuid"><xsl:copy-of select="@xmi:uuid"/></xsl:if>
      <xsl:attribute name="xmi:type" select="'uml:Association'"/>
      <!-- Copy @name and other non-structural attributes -->
      <xsl:for-each select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type','memberEnd'))]">
        <xsl:attribute name="{name()}" select="."/>
      </xsl:for-each>
      <!-- Convert space-separated @memberEnd attribute to child memberEnd elements -->
      <xsl:for-each select="tokenize(normalize-space(@memberEnd), '\s+')">
        <xsl:if test=". != ''">
          <memberEnd xmi:idref="{.}"/>
        </xsl:if>
      </xsl:for-each>
      <!-- Process child elements (ownedEnd etc.) normally -->
      <xsl:apply-templates select="*" mode="eclipse-preprocess"/>
    </xsl:element>
  </xsl:template>

  <xd:doc>
    <xd:short>Eclipse preprocess: Standard Profile stereotype application elements (Derive, Refine, Trace).</xd:short>
    <xd:detail>Passes through stereotype application elements from the Eclipse Standard Profile
    namespace, normalising the @base_Abstraction attribute to a child element with xmi:idref.
    The element local name (Derive, Refine, Trace) is preserved as a synthetic _stereotypeName
    attribute for the canonical pass to use when constructing the output element name.</xd:detail>
  </xd:doc>
  <xsl:template match="*[namespace-uri() = 'http://www.eclipse.org/uml2/5.0.0/UML/Profile/Standard']
                        [local-name() = ('Derive','Refine','Trace')]"
                mode="eclipse-preprocess">
    <_stereotypeApplication stereotypeName="{local-name()}">
      <xsl:copy-of select="@xmi:id | @xmi:uuid"/>
      <!-- Convert @base_Abstraction to child element with xmi:idref -->
      <xsl:if test="@base_Abstraction">
        <xsl:variable name="baseId" select="string(@base_Abstraction)"/>
        <xsl:variable name="resolvedIdref" as="xs:string">
          <xsl:choose>
            <xsl:when test="key('elementById', $baseId)">
              <xsl:value-of select="$baseId"/>
            </xsl:when>
            <!-- href fragment form -->
            <xsl:when test="starts-with($baseId, '#')">
              <xsl:value-of select="substring-after($baseId, '#')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$baseId"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <base_Abstraction xmi:idref="{$resolvedIdref}"/>
      </xsl:if>
    </_stereotypeApplication>
  </xsl:template>

  <xd:doc>
    <xd:short>Normalises an external profile stereotype application element into the intermediate tree.</xd:short>
    <xd:detail>Called from both EA and Eclipse preprocess paths for elements in the external profile
    namespace. Produces a _externalStereoApp synthetic element carrying the stereotype local name,
    the source xmi:id (if any), and the base_XXX reference as a child element with xmi:idref.
    The base attribute name (e.g. base_Association) is preserved so the canonical pass can emit it.</xd:detail>
  </xd:doc>
  <xsl:template name="normaliseExternalStereoApp">
    <xsl:variable name="stereoLocalName" select="local-name()"/>
    <!-- Find the base_XXX attribute (there is exactly one per Q6) -->
    <xsl:variable name="baseAttr"
      select="@*[starts-with(local-name(), 'base_')][1]"/>
    <xsl:if test="not($baseAttr)">
      <xsl:message>[WARNING] External profile stereotype element '<xsl:value-of select="$stereoLocalName"/>' has no base_XXX attribute — skipping.</xsl:message>
    </xsl:if>
    <xsl:if test="$baseAttr">
      <_externalStereoApp stereotypeName="{$stereoLocalName}"
                          baseAttrName="{local-name($baseAttr)}"
                          baseIdref="{string($baseAttr)}">
        <xsl:if test="@xmi:id">
          <xsl:attribute name="xmi:id" select="@xmi:id"/>
        </xsl:if>
        <xsl:if test="@xmi:uuid">
          <xsl:attribute name="xmi:uuid" select="@xmi:uuid"/>
        </xsl:if>
      </_externalStereoApp>
    </xsl:if>
  </xsl:template>

  <xd:doc>
    <xd:short>Eclipse preprocess: generic element pass-through with attribute-to-element conversion.</xd:short>
    <xd:detail>Suppresses elements in non-UML namespaces. Converts all non-XMI attributes to child elements.
    Infers missing xmi:type from element name. Converts in-file href to xmi:idref.</xd:detail>
  </xd:doc>
  <xsl:template match="*" mode="eclipse-preprocess">
    <!-- Suppress non-UML namespace elements;
         Standard Profile namespace is also passed through for stereotype applications -->
    <xsl:if test="namespace-uri() = ($UML_NS, $UML_NS_ECLIPSE, $XMI_NS,
                                      $STDPROFILE_NS_ECLIPSE, '')">
      <xsl:variable name="elemName" select="local-name()"/>
      <!-- Infer xmi:type if missing -->
      <xsl:variable name="inferredType" as="xs:string">
        <xsl:choose>
          <xsl:when test="@xmi:type"><xsl:value-of select="@xmi:type"/></xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="($elementTypeMap/entry[@elem=$elemName]/@type, '')[1]"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:element name="{$elemName}">
        <xsl:copy-of select="@xmi:id"/>
        <xsl:if test="@xmi:uuid"><xsl:copy-of select="@xmi:uuid"/></xsl:if>
        <xsl:if test="$inferredType != ''">
          <xsl:attribute name="xmi:type" select="$inferredType"/>
        </xsl:if>
        <!-- Convert href to xmi:idref if the target is in this document -->
        <xsl:for-each select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]">
          <xsl:variable name="attrName" select="name()"/>
          <xsl:variable name="attrVal"  select="string(.)"/>
          <xsl:choose>
            <!-- href: check if it resolves to an in-document element -->
            <xsl:when test="$attrName = 'href'">
              <xsl:variable name="fragment" select="substring-after($attrVal, '#')"/>
              <xsl:choose>
                <xsl:when test="$fragment != '' and key('elementById', $fragment)">
                  <xsl:attribute name="xmi:idref" select="$fragment"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:attribute name="href" select="$attrVal"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <!-- All other non-XMI attributes stored for canonical pass -->
            <xsl:otherwise>
              <xsl:attribute name="{$attrName}" select="$attrVal"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        <xsl:apply-templates select="* | text()" mode="eclipse-preprocess"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Pass text nodes through in eclipse-preprocess mode (e.g. body text of ownedComment) -->
  <xsl:template match="text()" mode="eclipse-preprocess">
    <xsl:copy/>
  </xsl:template>

  <!-- ============================================================
       SECTION 8: GENERIC PREPROCESS MODE
       ============================================================ -->

  <xd:doc>
    <xd:short>Generic preprocess: minimal pass-through for unrecognised input flavours.</xd:short>
  </xd:doc>
  <xsl:template match="/" mode="generic-preprocess">
    <xsl:choose>
      <xsl:when test="*[local-name()='XMI']/*[local-name()='Model']">
        <xsl:apply-templates
          select="(*[local-name()='XMI']/*[local-name()='Model'])[1]"
          mode="generic-copy"/>
      </xsl:when>
      <xsl:when test="*[local-name()='Model']">
        <xsl:apply-templates select="*[local-name()='Model']" mode="generic-copy"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">[ERROR] Cannot find uml:Model in input.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Generic-copy mode: renders a Model element as a uml:Model literal result element.</xd:short>
    <xd:detail>Used in generic preprocess for input that is neither EA nor Eclipse.
    Copies xmi:id, xmi:uuid, URI, and name attributes, then recurses into children.</xd:detail>
  </xd:doc>
  <xsl:template match="*[local-name()='Model']" mode="generic-copy">
    <uml:Model>
      <xsl:copy-of select="@xmi:id | @xmi:uuid"/>
      <!-- URI: from @URI attribute or child <URI> element (canonical form) -->
      <xsl:choose>
        <xsl:when test="@URI"><xsl:attribute name="URI" select="@URI"/></xsl:when>
        <xsl:when test="URI"><xsl:attribute name="URI" select="string(URI)"/></xsl:when>
      </xsl:choose>
      <!-- name: from @name attribute (EA/Eclipse/near-canonical)
                  or child <name> element (canonical form). -->
      <xsl:choose>
        <xsl:when test="normalize-space(@name) != ''">
          <xsl:attribute name="name" select="@name"/>
        </xsl:when>
        <xsl:when test="normalize-space(*[local-name()='name']) != ''">
          <xsl:attribute name="name" select="string(*[local-name()='name'])"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>[WARNING] uml:Model has no name attribute and no &lt;name&gt; child element. Model name will be empty.</xsl:message>
        </xsl:otherwise>
      </xsl:choose>
      <!-- Recurse into structural children, skipping simple-value elements -->
      <xsl:apply-templates
        select="*[not(local-name() = ('name','URI'))]"
        mode="generic-copy"/>
    </uml:Model>
  </xsl:template>

  <xd:doc>
    <xd:short>Generic-copy mode: pass-through for all UML-namespace elements.</xd:short>
    <xd:detail>Suppresses elements outside the UML or no-namespace. Handles both
    near-canonical input (properties as XML attributes) and true Canonical XMI input
    (properties as child elements). For Canonical XMI input, converts child elements
    such as name, URI, isAbstract, isReadOnly, isDerived, aggregation, client, supplier,
    association back to XML attributes so the canonical pass templates can read them
    consistently. type, general, memberEnd, lowerValue, upperValue, defaultValue,
    ownedComment, ownedAttribute, ownedEnd, generalization, ownedLiteral, and
    packagedElement children are passed through as child elements.</xd:detail>
  </xd:doc>
  <xsl:template match="*" mode="generic-copy">
    <xsl:if test="namespace-uri() = ($UML_NS, $UML_NS_ECLIPSE, '')">
      <xsl:element name="{local-name()}">
        <!-- Standard XMI identity attributes -->
        <xsl:copy-of select="@xmi:id | @xmi:uuid | @xmi:type"/>
        <!-- All other XML attributes (EA/Eclipse intermediate form) -->
        <xsl:copy-of select="@*[not(name() = ('xmi:id','xmi:uuid','xmi:type'))]"/>
        <!-- Canonical XMI form: child elements that represent simple property values
             are converted back to XML attributes for the canonical pass to read.
             Structural child elements (ownedAttribute, packagedElement, etc.)
             are passed through as child elements via apply-templates below. -->
        <!-- name: @name attribute (already copied above for near-canonical input),
             or <name> child element (canonical form) -->
        <xsl:if test="normalize-space(@name) = '' and
                      normalize-space(*[local-name()='name']) != ''">
          <xsl:attribute name="name" select="string(*[local-name()='name'])"/>
        </xsl:if>
        <!-- URI: <URI>text</URI> -> @URI -->
        <xsl:if test="not(@URI) and URI">
          <xsl:attribute name="URI" select="string(URI)"/>
        </xsl:if>
        <!-- Boolean properties: child element present means true -->
        <xsl:if test="not(@isAbstract) and isAbstract">
          <xsl:attribute name="isAbstract" select="string(isAbstract)"/>
        </xsl:if>
        <xsl:if test="not(@isReadOnly) and isReadOnly">
          <xsl:attribute name="isReadOnly" select="string(isReadOnly)"/>
        </xsl:if>
        <xsl:if test="not(@isDerived) and isDerived">
          <xsl:attribute name="isDerived" select="string(isDerived)"/>
        </xsl:if>
        <!-- aggregation: <aggregation>shared</aggregation> -> @aggregation -->
        <xsl:if test="not(@aggregation) and aggregation">
          <xsl:attribute name="aggregation" select="string(aggregation)"/>
        </xsl:if>
        <!-- client/supplier on Dependency/Abstraction: convert idref child to attribute -->
        <xsl:if test="not(@client) and client/@xmi:idref">
          <xsl:attribute name="client" select="client/@xmi:idref"/>
        </xsl:if>
        <xsl:if test="not(@supplier) and supplier/@xmi:idref">
          <xsl:attribute name="supplier" select="supplier/@xmi:idref"/>
        </xsl:if>
        <!-- association back-reference on ownedAttribute/ownedEnd -->
        <xsl:if test="not(@association) and association/@xmi:idref">
          <xsl:attribute name="association" select="association/@xmi:idref"/>
        </xsl:if>
        <!-- Recurse into structural children, skipping the simple-value elements
             already converted to attributes above -->
        <xsl:apply-templates
          select="*[not(local-name() = ('name','URI','isAbstract','isReadOnly',
                        'isDerived','aggregation','client','supplier','association'))]
                 | text()"
          mode="generic-copy"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Pass text nodes through in generic-copy mode (e.g. body text of ownedComment) -->
  <xsl:template match="text()" mode="generic-copy">
    <xsl:copy/>
  </xsl:template>

  <!-- ============================================================
       SECTION 9: CANONICAL MODE — ROOT
       ============================================================ -->

  <xd:doc>
    <xd:short>Canonical mode root: emits the xmi:XMI wrapper with namespace declarations.</xd:short>
  </xd:doc>
  <xsl:template match="/" mode="canonical">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <!-- Collect all Abstraction elements with stereotype applications from intermediate tree.
         EA: identified by _stereotype synthetic child element.
         Eclipse: identified by _stereotypeApplication synthetic element siblings of Model. -->
    <xsl:variable name="abstractionsWithStereo"
      select="*[local-name()='Model']//packagedElement[@xmi:type='uml:Abstraction'][_stereotype]
              | *[local-name()='Model']//packagedElement[@xmi:type='uml:Abstraction']
                  [base_Abstraction or ../_stereotypeApplication[@xmi:id]]"/>
    <!-- Eclipse: _stereotypeApplication elements are siblings of uml:Model -->
    <xsl:variable name="eclipseStereoApps"
      select="*[local-name()='_stereotypeApplication']"/>
    <xsl:variable name="hasStereotypes"
      select="exists(*[local-name()='Model']//packagedElement[@xmi:type='uml:Abstraction'][_stereotype])
              or exists($eclipseStereoApps)"/>
    <xsl:variable name="hasExternalStereo"
      select="$profilePrefix != '' and $effectiveProfileNsURI != ''
              and exists(*[local-name()='_externalStereoApp'])"/>
    <xmi:XMI>
      <xsl:namespace name="xmi" select="$XMI_NS"/>
      <xsl:namespace name="uml" select="if ($eclipseOutput='yes') then $UML_NS_ECLIPSE else $UML_NS"/>
      <!-- Declare StandardProfile namespace only when stereotype applications are present -->
      <xsl:if test="$hasStereotypes">
        <xsl:variable name="stereoNS"
          select="if ($eclipseOutput='yes') then $STDPROFILE_NS_ECLIPSE else $STDPROFILE_NS"/>
        <xsl:variable name="stereoPrefix"
          select="if ($eclipseOutput='yes') then 'Standard' else 'StandardProfile'"/>
        <xsl:namespace name="{$stereoPrefix}" select="$stereoNS"/>
      </xsl:if>
      <!-- Declare external profile namespace before any child elements -->
      <xsl:if test="$hasExternalStereo">
        <xsl:namespace name="{$profilePrefix}" select="$effectiveProfileNsURI"/>
      </xsl:if>
      <!-- Emit the uml:Model first (Option B: model before stereotype applications) -->
      <xsl:apply-templates select="*[local-name()='Model']" mode="canonical"/>
      <!-- Emit stereotype application elements after uml:Model,
           sorted by stereotype name then xmi:uuid (B.5.1 within the stereotype group) -->
      <!-- EA path: collect from _stereotype synthetic children on Abstraction elements -->
      <xsl:for-each
        select="*[local-name()='Model']//packagedElement[@xmi:type='uml:Abstraction'][_stereotype]">
        <xsl:sort select="_stereotype/@name"/>
        <xsl:sort select="@xmi:uuid"/>
        <xsl:variable name="abstractionNode" select="."/>
        <xsl:variable name="stereoName"      select="_stereotype/@name"/>
        <xsl:variable name="createdName">
          <xsl:call-template name="computeCreatedName">
            <xsl:with-param name="node" select="."/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="emitStereotypeApplication">
          <xsl:with-param name="stereotypeName"        select="$stereoName"/>
          <xsl:with-param name="abstractionNode"        select="$abstractionNode"/>
          <xsl:with-param name="abstractionCreatedName" select="$createdName"/>
        </xsl:call-template>
      </xsl:for-each>
      <!-- Eclipse path: _stereotypeApplication synthetic elements -->
      <xsl:for-each select="$eclipseStereoApps">
        <xsl:sort select="@stereotypeName"/>
        <xsl:sort select="@xmi:uuid"/>
        <xsl:variable name="stereoName"   select="@stereotypeName"/>
        <xsl:variable name="baseIdref"    select="base_Abstraction/@xmi:idref"/>
        <!-- Find the corresponding Abstraction in the intermediate tree.
             Context node "." is the intermediate tree document node in this template,
             so *[1] gives the root uml:Model element for key() scoping. -->
        <xsl:variable name="abstractionNode"
          select="key('interById', $baseIdref, *[1])"/>
        <xsl:variable name="createdName">
          <xsl:call-template name="computeCreatedName">
            <xsl:with-param name="node" select="$abstractionNode"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="emitStereotypeApplication">
          <xsl:with-param name="stereotypeName"        select="$stereoName"/>
          <xsl:with-param name="abstractionNode"        select="$abstractionNode"/>
          <xsl:with-param name="abstractionCreatedName" select="$createdName"/>
        </xsl:call-template>
      </xsl:for-each>
      <!-- External profile stereotype applications (after Standard Profile, sorted by name then uuid) -->
      <xsl:if test="$hasExternalStereo">
        <xsl:for-each select="*[local-name()='_externalStereoApp']">
          <xsl:sort select="@stereotypeName"/>
          <xsl:sort select="@xmi:uuid"/>
          <xsl:call-template name="emitExternalStereoApplication">
            <xsl:with-param name="stereoApp" select="."/>
          </xsl:call-template>
        </xsl:for-each>
      </xsl:if>
    </xmi:XMI>
  </xsl:template>

  <!-- ============================================================
       SECTION 10: CANONICAL MODE — uml:Model
       ============================================================ -->

  <xd:doc>
    <xd:short>Canonical mode: renders the uml:Model root element.</xd:short>
  </xd:doc>
  <xsl:template match="*[local-name()='Model']" mode="canonical">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <!-- Resolve prefix for this model from PackageInformation DataType if present -->
    <xsl:variable name="localPrefix" as="xs:string">
      <xsl:call-template name="resolvePackagePrefix">
        <xsl:with-param name="packageNode" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="localNsURI" as="xs:string">
      <xsl:call-template name="resolvePackageNsURI">
        <xsl:with-param name="packageNode" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <!-- Use xsl:element with computed namespace so eclipseOutput controls
         whether the element is in the Eclipse or OMG UML namespace,
         matching the xmlns:uml declaration on the parent xmi:XMI element. -->
    <xsl:variable name="umlNS"
      select="if ($eclipseOutput='yes') then $UML_NS_ECLIPSE else $UML_NS"/>
    <xsl:element name="uml:Model" namespace="{$umlNS}">
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="string(@name)"/>
        <xsl:with-param name="prefix" select="$localPrefix"/>
        <xsl:with-param name="nsURI"  select="$localNsURI"/>
      </xsl:call-template>
      <!-- xmi:type on uml:Model is omitted per Q58 reversal — B.2.6 strictly requires it -->
      <xsl:attribute name="xmi:type" select="'uml:Model'"/>
      <!-- Properties in canonical order for Package/Model: ownedComment, name, URI, packagedElement -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="prefix"    select="$localPrefix" tunnel="yes"/>
        <xsl:with-param name="nsURI"     select="$localNsURI"  tunnel="yes"/>
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="string(@name)"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <xsl:if test="@URI">
        <URI><xsl:value-of select="@URI"/></URI>
      </xsl:if>
      <!-- packagedElement children sorted by xmi:type then xmi:uuid (B.5.1 / Q35) -->
      <!-- Pass localPrefix to all children so nested packages inherit it until overridden -->
      <xsl:apply-templates select="packagedElement" mode="canonical">
        <xsl:with-param name="prefix" select="$localPrefix" tunnel="yes"/>
        <xsl:with-param name="nsURI"  select="$localNsURI"  tunnel="yes"/>
        <xsl:sort select="@xmi:type"/>
        <xsl:sort select="@xmi:uuid"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       SECTION 11: CANONICAL MODE — packagedElement dispatch
       ============================================================ -->

  <xd:doc>
    <xd:short>Canonical mode: dispatch for packagedElement by xmi:type.</xd:short>
  </xd:doc>
  <xsl:template match="packagedElement" mode="canonical">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <xsl:variable name="type" select="@xmi:type"/>
    <xsl:choose>
      <xsl:when test="$type = 'uml:Class'">
        <xsl:call-template name="emitClass"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:DataType'">
        <xsl:call-template name="emitDataType"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:Enumeration'">
        <xsl:call-template name="emitEnumeration"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:PrimitiveType'">
        <xsl:call-template name="emitPrimitiveType"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:Association'">
        <xsl:call-template name="emitAssociation"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:Dependency'">
        <xsl:call-template name="emitDependency"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:Abstraction'">
        <xsl:call-template name="emitAbstraction"/>
      </xsl:when>
      <xsl:when test="$type = 'uml:Package'">
        <xsl:call-template name="emitPackage"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>[WARNING] Unrecognised packagedElement type '<xsl:value-of select="$type"/>' — suppressing.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 12: CANONICAL MODE — uml:Package
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Package packagedElement in canonical form.</xd:short>
  </xd:doc>
  <xsl:template name="emitPackage">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <!-- Resolve prefix for this package from PackageInformation DataType if present -->
    <xsl:variable name="localPrefix" as="xs:string">
      <xsl:call-template name="resolvePackagePrefix">
        <xsl:with-param name="packageNode" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="localNsURI" as="xs:string">
      <xsl:call-template name="resolvePackageNsURI">
        <xsl:with-param name="packageNode" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="string($localName)"/>
        <xsl:with-param name="prefix" select="$localPrefix"/>
        <xsl:with-param name="nsURI"  select="$localNsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Package'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="prefix" select="$localPrefix" tunnel="yes"/>
        <xsl:with-param name="nsURI"  select="$localNsURI"  tunnel="yes"/>
        <xsl:with-param name="ownerId" select="@xmi:id"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <xsl:if test="@URI">
        <URI><xsl:value-of select="@URI"/></URI>
      </xsl:if>
      <xsl:apply-templates select="packagedElement" mode="canonical">
        <xsl:with-param name="prefix" select="$localPrefix" tunnel="yes"/>
        <xsl:with-param name="nsURI"  select="$localNsURI"  tunnel="yes"/>
        <xsl:sort select="@xmi:type"/>
        <xsl:sort select="@xmi:uuid"/>
      </xsl:apply-templates>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 13: CANONICAL MODE — uml:Class
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Class packagedElement in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, isAbstract, generalization, ownedAttribute.</xd:detail>
  </xd:doc>
  <xsl:template name="emitClass">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Proxy detection: name was an IRI stripped to a local name -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="string($localName) != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="string($localName)"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Class'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="string($localName)"/>
      </xsl:apply-templates>
      <!-- 2. name -->
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <!-- 3. isAbstract (only if true) -->
      <xsl:if test="@isAbstract = 'true'">
        <isAbstract>true</isAbstract>
      </xsl:if>
      <!-- 4. generalization -->
      <xsl:for-each select="generalization">
        <xsl:call-template name="emitGeneralization"/>
      </xsl:for-each>
      <!-- 5. ownedAttribute -->
      <xsl:for-each select="ownedAttribute">
        <xsl:call-template name="emitProperty"/>
      </xsl:for-each>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 14: CANONICAL MODE — uml:DataType
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:DataType packagedElement in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, isAbstract, ownedAttribute.</xd:detail>
  </xd:doc>
  <xsl:template name="emitDataType">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Proxy detection: name was an IRI stripped to a local name -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="string($localName) != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="string($localName)"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:DataType'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId" select="@xmi:id"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <xsl:if test="@isAbstract = 'true'">
        <isAbstract>true</isAbstract>
      </xsl:if>
      <xsl:for-each select="ownedAttribute">
        <xsl:call-template name="emitProperty"/>
      </xsl:for-each>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 15: CANONICAL MODE — uml:Enumeration
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Enumeration packagedElement in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, isAbstract, ownedAttribute, ownedLiteral.</xd:detail>
  </xd:doc>
  <xsl:template name="emitEnumeration">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Proxy detection: name was an IRI stripped to a local name -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="string($localName) != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="string($localName)"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Enumeration'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId" select="@xmi:id"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <xsl:if test="@isAbstract = 'true'">
        <isAbstract>true</isAbstract>
      </xsl:if>
      <xsl:for-each select="ownedAttribute">
        <xsl:call-template name="emitProperty"/>
      </xsl:for-each>
      <xsl:for-each select="ownedLiteral">
        <xsl:call-template name="emitEnumerationLiteral"/>
      </xsl:for-each>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 16: CANONICAL MODE — uml:PrimitiveType
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a user-defined uml:PrimitiveType packagedElement in canonical form.</xd:short>
  </xd:doc>
  <xsl:template name="emitPrimitiveType">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Proxy detection: name was an IRI stripped to a local name -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="string($localName) != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="string($localName)"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:PrimitiveType'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId" select="@xmi:id"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 17: CANONICAL MODE — uml:Association
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Association packagedElement in canonical form.</xd:short>
    <xd:detail>Property order per B.5.3: ownedComment, name, then nested elements (ownedEnd)
    before link elements (memberEnd). Handles qualified association name generation/validation.</xd:detail>
  </xd:doc>
  <xsl:template name="emitAssociation">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <!-- Determine effective association name -->
    <xsl:variable name="localName">
      <xsl:call-template name="deriveLocalName">
        <xsl:with-param name="rawName" select="string(@name)"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="sourceName" select="string($localName)"/>
    <xsl:variable name="effectiveName" as="xs:string">
      <xsl:choose>
        <xsl:when test="$qualifiedAssocNames = 'yes'">
          <xsl:call-template name="deriveQualifiedAssocName">
            <xsl:with-param name="assoc" select="."/>
            <xsl:with-param name="sourceName" select="$sourceName"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$sourceName"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <packagedElement>
      <!-- Proxy detection: sourceName was stripped from an IRI -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="$sourceName != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="$effectiveName"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Association'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$effectiveName"/>
      </xsl:apply-templates>
      <!-- 2. name -->
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="$effectiveName"/>
      </xsl:call-template>
      <!-- 3. ownedEnd (nested element, before memberEnd links per B.5.3) -->
      <xsl:for-each select="ownedEnd">
        <xsl:call-template name="emitOwnedEnd">
          <xsl:with-param name="assocId"          select="../@xmi:id"/>
          <xsl:with-param name="assocCreatedName" select="$effectiveName"/>
        </xsl:call-template>
      </xsl:for-each>
      <!-- 4. memberEnd (link elements — self-closing xmi:idref) -->
      <xsl:for-each select="memberEnd">
        <xsl:variable name="meIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@xmi:idref"/>
          </xsl:call-template>
        </xsl:variable>
        <memberEnd xmi:idref="{$meIdref}"/>
      </xsl:for-each>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 18: CANONICAL MODE — uml:Dependency
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Dependency packagedElement in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, client, supplier.
    client and supplier become self-closing xmi:idref child elements (same-file references).</xd:detail>
  </xd:doc>
  <xsl:template name="emitDependency">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <packagedElement>
      <xsl:variable name="localName">
        <xsl:call-template name="deriveLocalName">
          <xsl:with-param name="rawName" select="string(@name)"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Qualified name: SubjectClass_verb_ObjectClass when qualifiedAssocNames=yes.
           Applies to uml:Dependency the same way as uml:Abstraction and uml:Association,
           ensuring uniqueness when multiple dependencies share the same short name. -->
      <xsl:variable name="sourceName" select="string($localName)"/>
      <xsl:variable name="effectiveName" as="xs:string">
        <xsl:choose>
          <xsl:when test="$qualifiedAssocNames = 'yes'">
            <xsl:call-template name="deriveQualifiedAbstractionName">
              <xsl:with-param name="sourceName" select="$sourceName"/>
              <xsl:with-param name="clientId"   select="string(@client)"/>
              <xsl:with-param name="supplierId" select="string(@supplier)"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$sourceName"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Proxy detection: name was an IRI stripped to a local name -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="string($localName) != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="$effectiveName"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Dependency'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$effectiveName"/>
      </xsl:apply-templates>
      <!-- 2. name -->
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <!-- 3. client — same-file idref -->
      <xsl:if test="@client">
        <xsl:variable name="clientIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@client"/>
          </xsl:call-template>
        </xsl:variable>
        <client xmi:idref="{$clientIdref}"/>
      </xsl:if>
      <!-- 4. supplier — same-file idref or href for cross-model -->
      <xsl:if test="@supplier">
        <xsl:variable name="supplierIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@supplier"/>
          </xsl:call-template>
        </xsl:variable>
        <supplier xmi:idref="{$supplierIdref}"/>
      </xsl:if>
    </packagedElement>
  </xsl:template>

  <!-- ============================================================
       SECTION 18b: CANONICAL MODE — uml:Abstraction
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a uml:Abstraction packagedElement in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, client, supplier.
    Qualified name follows the same pattern as Association when qualifiedAssocNames=yes.
    The _stereotype synthetic child (from ea-preprocess) or _stereotypeApplication
    (from eclipse-preprocess) is not emitted here — stereotype application elements
    are collected and emitted as top-level xmi:XMI children by the canonical root template.</xd:detail>
  </xd:doc>
  <xsl:template name="emitAbstraction">
    <xsl:param name="nsURI"     tunnel="yes"/>
    <xsl:param name="prefix"    tunnel="yes"/>
    <xsl:param name="sourceRoot" tunnel="yes"/>
    <!-- Determine effective name (qualified if qualifiedAssocNames=yes).
         For Abstraction the subject/object classes come directly from @client/@supplier
         attributes, unlike Association which uses memberEnd child elements. -->
    <xsl:variable name="localName">
      <xsl:call-template name="deriveLocalName">
        <xsl:with-param name="rawName" select="string(@name)"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="sourceName" select="string($localName)"/>
    <xsl:variable name="effectiveName" as="xs:string">
      <xsl:choose>
        <xsl:when test="$qualifiedAssocNames = 'yes'">
          <xsl:call-template name="deriveQualifiedAbstractionName">
            <xsl:with-param name="sourceName" select="$sourceName"/>
            <xsl:with-param name="clientId"   select="string(@client)"/>
            <xsl:with-param name="supplierId" select="string(@supplier)"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$sourceName"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <packagedElement>
      <!-- Proxy detection: sourceName was stripped from an IRI -->
      <xsl:variable name="isProxy" as="xs:boolean"
        select="$sourceName != string(@name)"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"     select="."/>
        <xsl:with-param name="name"     select="$effectiveName"/>
        <xsl:with-param name="isProxy"  select="$isProxy"/>
        <xsl:with-param name="prefix"   select="$prefix"/>
        <xsl:with-param name="nsURI"    select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Abstraction'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$effectiveName"/>
      </xsl:apply-templates>
      <!-- 2. name -->
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="$effectiveName"/>
      </xsl:call-template>
      <!-- 3. client — same-file idref -->
      <xsl:if test="@client">
        <xsl:variable name="clientIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@client"/>
          </xsl:call-template>
        </xsl:variable>
        <client xmi:idref="{$clientIdref}"/>
      </xsl:if>
      <!-- 4. supplier — same-file idref -->
      <xsl:if test="@supplier">
        <xsl:variable name="supplierIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@supplier"/>
          </xsl:call-template>
        </xsl:variable>
        <supplier xmi:idref="{$supplierIdref}"/>
      </xsl:if>
    </packagedElement>
  </xsl:template>

  <xd:doc>
    <xd:short>Derives a qualified name for a uml:Abstraction from its client and supplier ids.</xd:short>
    <xd:detail>Resolves the client (subject) and supplier (object) class names directly from
    the @client and @supplier attributes on the Abstraction element, then constructs
    SubjectClass_shortName_ObjectClass. When sourceHasQualifiedNames=yes, the source name
    is preserved and only validated. Unlike deriveQualifiedAssocName, no memberEnd lookup
    is required — client and supplier ids are available directly.</xd:detail>
    <xd:param name="sourceName"  type="xs:string">The source association name.</xd:param>
    <xd:param name="clientId"    type="xs:string">The xmi:id of the client (subject) element.</xd:param>
    <xd:param name="supplierId"  type="xs:string">The xmi:id of the supplier (object) element.</xd:param>
  </xd:doc>
  <xsl:template name="deriveQualifiedAbstractionName">
    <xsl:param name="sourceName"  as="xs:string"/>
    <xsl:param name="clientId"    as="xs:string"/>
    <xsl:param name="supplierId"  as="xs:string"/>
    <xsl:param name="sourceRoot"  tunnel="yes"/>
    <!-- Resolve class names from source document -->
    <xsl:variable name="subjectClass"
      select="key('elementById', $clientId,   $sourceRoot)/@name"/>
    <xsl:variable name="objectClass"
      select="key('elementById', $supplierId, $sourceRoot)/@name"/>
    <!-- Extract short name -->
    <xsl:variable name="shortName" as="xs:string">
      <xsl:choose>
        <xsl:when test="$sourceHasQualifiedNames = 'yes' and contains($sourceName, '_')">
          <xsl:variable name="parts" select="tokenize($sourceName, '_')"/>
          <xsl:value-of
            select="string-join($parts[position() > 1 and position() &lt; last()], '_')"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$sourceName"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="derivedName"
      select="concat($subjectClass, '_', $shortName, '_', $objectClass)"/>
    <xsl:choose>
      <xsl:when test="$sourceHasQualifiedNames = 'yes'">
        <xsl:if test="$subjectClass != '' and $objectClass != ''
                      and $sourceName != $derivedName">
          <xsl:message>[WARNING] Qualified abstraction name mismatch: source='<xsl:value-of
            select="$sourceName"/>' derived='<xsl:value-of select="$derivedName"/>'. Using source name.</xsl:message>
        </xsl:if>
        <xsl:value-of select="$sourceName"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="$subjectClass = '' or $objectClass = ''">
          <xsl:message>[WARNING] Cannot resolve client/supplier class names for Abstraction '<xsl:value-of
            select="$sourceName"/>'. Using source name unchanged.</xsl:message>
          <xsl:value-of select="$sourceName"/>
        </xsl:if>
        <xsl:if test="$subjectClass != '' and $objectClass != ''">
          <xsl:value-of select="$derivedName"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Emits a single StandardProfile stereotype application element as a top-level xmi:XMI child.</xd:short>
    <xd:detail>Emits StandardProfile:Derive, StandardProfile:Refine, or StandardProfile:Trace
    (or their Eclipse equivalents) with xmi:id, xmi:uuid, and a base_Abstraction child element.
    The output namespace is determined by eclipseOutput.</xd:detail>
    <xd:param name="stereotypeName" type="xs:string">The stereotype name: Derive, Refine, or Trace.</xd:param>
    <xd:param name="abstractionNode" type="element()">The Abstraction packagedElement in the intermediate tree.</xd:param>
    <xd:param name="abstractionCreatedName" type="xs:string">The createdName of the Abstraction (for id generation).</xd:param>
  </xd:doc>
  <xsl:template name="emitStereotypeApplication">
    <xsl:param name="stereotypeName"         as="xs:string"/>
    <xsl:param name="abstractionNode"         as="element()"/>
    <xsl:param name="abstractionCreatedName"  as="xs:string"/>
    <xsl:param name="nsURI"                   tunnel="yes"/>
    <xsl:param name="prefix"                  tunnel="yes"/>
    <xsl:param name="intermediateRoot"        tunnel="yes"/>
    <!-- createdName for the stereotype application element -->
    <xsl:variable name="stereoCreatedName"
      select="concat($abstractionCreatedName, '-', $stereotypeName)"/>
    <!-- Output namespace driven by eclipseOutput -->
    <xsl:variable name="stereoNS"
      select="if ($eclipseOutput = 'yes') then $STDPROFILE_NS_ECLIPSE else $STDPROFILE_NS"/>
    <xsl:variable name="stereoPrefix"
      select="if ($eclipseOutput = 'yes') then 'Standard' else 'StandardProfile'"/>
    <xsl:element name="{$stereoPrefix}:{$stereotypeName}" namespace="{$stereoNS}">
      <!-- xmi:id and xmi:uuid -->
      <xsl:choose>
        <xsl:when test="$generateIds = 'yes'">
          <xsl:attribute name="xmi:id"   select="concat($prefix, '.', $stereoCreatedName)"/>
          <xsl:attribute name="xmi:uuid" select="concat($nsURI, '#', $stereoCreatedName)"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Pass through source id from the abstraction node's _stereotypeApplication
               or _stereotype child if available; otherwise generate -->
          <xsl:attribute name="xmi:id"
            select="concat($prefix, '.', $stereoCreatedName)"/>
        </xsl:otherwise>
      </xsl:choose>
      <!-- base_Abstraction child element pointing to the Abstraction packagedElement -->
      <xsl:variable name="abstractionCanonicalId">
        <xsl:call-template name="resolveIdref">
          <xsl:with-param name="sourceId" select="string($abstractionNode/@xmi:id)"/>
        </xsl:call-template>
      </xsl:variable>
      <base_Abstraction xmi:idref="{$abstractionCanonicalId}"/>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       SECTION 18c: CANONICAL MODE — External profile stereotype application
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits an external profile stereotype application element as a top-level xmi:XMI child.</xd:short>
    <xd:detail>Uses the profilePrefix and effectiveProfileNsURI to construct the output element
    in the correct namespace. Generates xmi:id and xmi:uuid. Emits the base_XXX reference
    as a child element with xmi:idref resolved to the canonical id.</xd:detail>
    <xd:param name="stereoApp" type="element()">The _externalStereoApp synthetic element.</xd:param>
  </xd:doc>
  <xsl:template name="emitExternalStereoApplication">
    <xsl:param name="stereoApp"  as="element()"/>
    <xsl:param name="nsURI"      tunnel="yes"/>
    <xsl:param name="prefix"     tunnel="yes"/>
    <xsl:param name="intermediateRoot" tunnel="yes"/>
    <xsl:variable name="stereoName"   select="$stereoApp/@stereotypeName"/>
    <xsl:variable name="baseAttrName" select="$stereoApp/@baseAttrName"/>
    <xsl:variable name="sourceBaseId" select="string($stereoApp/@baseIdref)"/>
    <!-- Resolve the base element id to its canonical form -->
    <xsl:variable name="resolvedBaseId">
      <xsl:call-template name="resolveIdref">
        <xsl:with-param name="sourceId" select="$sourceBaseId"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- createdName: stereoLocalName-resolvedBaseId (with safe chars) -->
    <xsl:variable name="createdName"
      select="concat($stereoName, '-', replace($resolvedBaseId, '[^A-Za-z0-9_\-\.]', '_'))"/>
    <!-- Output element in external profile namespace -->
    <xsl:element name="{$profilePrefix}:{$stereoName}"
                 namespace="{$effectiveProfileNsURI}">
      <xsl:choose>
        <xsl:when test="$generateIds = 'yes'">
          <xsl:attribute name="xmi:id"   select="concat($prefix, '.', $createdName)"/>
          <xsl:attribute name="xmi:uuid" select="concat($nsURI, '#', $createdName)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:if test="$stereoApp/@xmi:id">
            <xsl:attribute name="xmi:id"   select="$stereoApp/@xmi:id"/>
          </xsl:if>
          <xsl:if test="$stereoApp/@xmi:uuid">
            <xsl:attribute name="xmi:uuid" select="$stereoApp/@xmi:uuid"/>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
      <!-- base_XXX child element with resolved xmi:idref -->
      <xsl:element name="{$baseAttrName}">
        <xsl:attribute name="xmi:idref" select="$resolvedBaseId"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       SECTION 19: CANONICAL MODE — uml:Property (ownedAttribute)
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits an ownedAttribute (uml:Property) in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name, isReadOnly, isDerived, type,
    lowerValue, upperValue, defaultValue, association, aggregation.</xd:detail>
  </xd:doc>
  <xsl:template name="emitProperty">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <ownedAttribute>
      <xsl:variable name="propCreatedName" as="xs:string">
        <xsl:choose>
          <xsl:when test="normalize-space(@name) != ''">
            <xsl:value-of select="concat(string(parent::*/@name), '-', string(@name))"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- Anonymous association end: use parent class name + index -->
            <xsl:value-of select="concat(parent::*/@name, '-ownedAttribute-',
                                         count(preceding-sibling::ownedAttribute) + 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="$propCreatedName"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Property'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$propCreatedName"/>
      </xsl:apply-templates>
      <!-- 2. name (omit if empty/absent — e.g. anonymous association end) -->
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
      <!-- 3. isReadOnly (only if true) -->
      <xsl:if test="@isReadOnly = 'true'">
        <isReadOnly>true</isReadOnly>
      </xsl:if>
      <!-- 4. isDerived (only if true) -->
      <xsl:if test="@isDerived = 'true'">
        <isDerived>true</isDerived>
      </xsl:if>
      <!-- 5. type — may be a child element (EA) or @type XML attribute (Eclipse) -->
      <xsl:choose>
        <xsl:when test="type">
          <xsl:apply-templates select="type" mode="canonical-ref"/>
        </xsl:when>
        <xsl:when test="@type and @type != ''">
          <!-- Eclipse: type is an XML attribute holding a same-file xmi:id -->
          <xsl:variable name="resolvedTypeId">
            <xsl:call-template name="resolveIdref">
              <xsl:with-param name="sourceId" select="string(@type)"/>
            </xsl:call-template>
          </xsl:variable>
          <type xmi:idref="{$resolvedTypeId}"/>
        </xsl:when>
      </xsl:choose>
      <!-- 6. lowerValue — omit if default (1) or absent; emit without <value> if 0 -->
      <xsl:call-template name="emitLowerValue">
        <xsl:with-param name="ownerName" select="$propCreatedName"/>
      </xsl:call-template>
      <!-- 7. upperValue — omit if default (1) or absent -->
      <xsl:call-template name="emitUpperValue">
        <xsl:with-param name="ownerName" select="$propCreatedName"/>
      </xsl:call-template>
      <!-- 8. defaultValue -->
      <xsl:apply-templates select="defaultValue" mode="canonical-value">
        <xsl:with-param name="ownerId" select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="concat(string(parent::*/@name), '-', string(@name))"/>
      </xsl:apply-templates>
      <!-- 9. association (opposite property — required by B.2.12) -->
      <xsl:if test="@association">
        <xsl:variable name="assocIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@association"/>
          </xsl:call-template>
        </xsl:variable>
        <association xmi:idref="{$assocIdref}"/>
      </xsl:if>
      <!-- 10. aggregation (only if non-default) -->
      <xsl:if test="@aggregation and @aggregation != 'none'">
        <aggregation><xsl:value-of select="@aggregation"/></aggregation>
      </xsl:if>
    </ownedAttribute>
  </xsl:template>

  <!-- ============================================================
       SECTION 20: CANONICAL MODE — ownedEnd (Association end)
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits an ownedEnd (non-navigable association end) in canonical form.</xd:short>
    <xd:param name="assocId" type="xs:string">The xmi:id of the owning Association.</xd:param>
  </xd:doc>
  <xsl:template name="emitOwnedEnd">
    <xsl:param name="assocId"          as="xs:string"/>
    <!-- assocCreatedName: the qualified/effective association name used for id generation.
         Passed from emitAssociation so the ownedEnd id matches the association id. -->
    <xsl:param name="assocCreatedName" as="xs:string" select="string(parent::*/@name)"/>
    <xsl:param name="nsURI"            tunnel="yes"/>
    <xsl:param name="prefix"           tunnel="yes"/>
    <ownedEnd>
      <!-- Build a unique createdName using the type class name to disambiguate
           when an Association owns multiple ownedEnd elements. -->
      <xsl:variable name="oeTypeIdref" select="(type/@xmi:idref, @type)[normalize-space(.)!=''][1]"/>
      <xsl:variable name="oeTypeName"  select="key('elementById', $oeTypeIdref)/@name"/>
      <xsl:variable name="oeCreatedName" as="xs:string">
        <xsl:choose>
          <xsl:when test="normalize-space($oeTypeName) != ''">
            <xsl:value-of select="concat($assocCreatedName, '-ownedEnd-', $oeTypeName)"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- Fallback: positional suffix -->
            <xsl:value-of select="concat($assocCreatedName, '-ownedEnd-',
              count(preceding-sibling::ownedEnd) + 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="$oeCreatedName"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Property'"/>
      <!-- 1. ownedComment -->
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$oeCreatedName"/>
      </xsl:apply-templates>
      <!-- No name element for anonymous ownedEnd (Q12) -->
      <!-- isReadOnly, isDerived if present -->
      <xsl:if test="@isReadOnly = 'true'"><isReadOnly>true</isReadOnly></xsl:if>
      <xsl:if test="@isDerived = 'true'"><isDerived>true</isDerived></xsl:if>
      <!-- type -->
      <!-- type ref — may be child element (EA) or @type XML attribute (Eclipse) -->
      <xsl:choose>
        <xsl:when test="type">
          <xsl:apply-templates select="type" mode="canonical-ref"/>
        </xsl:when>
        <xsl:when test="@type and @type != ''">
          <xsl:variable name="resolvedTypeId">
            <xsl:call-template name="resolveIdref">
              <xsl:with-param name="sourceId" select="string(@type)"/>
            </xsl:call-template>
          </xsl:variable>
          <type xmi:idref="{$resolvedTypeId}"/>
        </xsl:when>
      </xsl:choose>
      <!-- lowerValue / upperValue -->
      <xsl:call-template name="emitLowerValue">
        <xsl:with-param name="ownerName" select="$oeCreatedName"/>
      </xsl:call-template>
      <xsl:call-template name="emitUpperValue">
        <xsl:with-param name="ownerName" select="$oeCreatedName"/>
      </xsl:call-template>
      <!-- association (opposite property, B.2.12) -->
      <xsl:variable name="oeAssocIdref">
        <xsl:call-template name="resolveIdref">
          <xsl:with-param name="sourceId" select="$assocId"/>
        </xsl:call-template>
      </xsl:variable>
      <association xmi:idref="{$oeAssocIdref}"/>
      <!-- aggregation -->
      <xsl:if test="@aggregation and @aggregation != 'none'">
        <aggregation><xsl:value-of select="@aggregation"/></aggregation>
      </xsl:if>
    </ownedEnd>
  </xsl:template>

  <!-- ============================================================
       SECTION 21: CANONICAL MODE — generalization
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a generalization element in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, general.</xd:detail>
  </xd:doc>
  <xsl:template name="emitGeneralization">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <xsl:variable name="genCreatedName"
      select="concat(parent::*/@name, '-generalization')"/>
    <generalization>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="$genCreatedName"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Generalization'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId"   select="@xmi:id"/>
        <xsl:with-param name="ownerName" select="$genCreatedName"/>
      </xsl:apply-templates>
      <!-- general: prefer child element, fall back to @general attribute -->
      <xsl:choose>
        <xsl:when test="general">
          <xsl:apply-templates select="general" mode="canonical-ref"/>
        </xsl:when>
        <xsl:when test="@general">
          <xsl:variable name="genIdref">
            <xsl:call-template name="resolveIdref">
              <xsl:with-param name="sourceId" select="@general"/>
            </xsl:call-template>
          </xsl:variable>
          <general xmi:idref="{$genIdref}"/>
        </xsl:when>
      </xsl:choose>
    </generalization>
  </xsl:template>

  <!-- ============================================================
       SECTION 22: CANONICAL MODE — EnumerationLiteral
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits an ownedLiteral (uml:EnumerationLiteral) in canonical form.</xd:short>
    <xd:detail>Property order: ownedComment, name.</xd:detail>
  </xd:doc>
  <xsl:template name="emitEnumerationLiteral">
    <xsl:param name="nsURI"  tunnel="yes"/>
    <xsl:param name="prefix" tunnel="yes"/>
    <ownedLiteral>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="concat(string(parent::*/@name), '-', string(@name))"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:EnumerationLiteral'"/>
      <xsl:apply-templates select="ownedComment" mode="canonical-comment">
        <xsl:with-param name="ownerId" select="@xmi:id"/>
      </xsl:apply-templates>
      <xsl:call-template name="emitNameElement">
        <xsl:with-param name="name" select="string(@name)"/>
      </xsl:call-template>
    </ownedLiteral>
  </xsl:template>

  <!-- ============================================================
       SECTION 23: CANONICAL MODE — ownedComment
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits an ownedComment (uml:Comment) with body and annotatedElement in canonical form.</xd:short>
    <xd:param name="ownerId" type="xs:string">The xmi:id of the annotated owning element.</xd:param>
  </xd:doc>
  <xsl:template match="ownedComment" mode="canonical-comment">
    <xsl:param name="ownerId"   as="xs:string"/>
    <xsl:param name="ownerName" as="xs:string" select="string(parent::*/@name)"/>
    <xsl:param name="nsURI"     tunnel="yes"/>
    <xsl:param name="prefix"    tunnel="yes"/>
    <xsl:variable name="bodyText" select="(@_body, body, text())[normalize-space(.)!=''][1]"/>
    <xsl:variable name="annotId"  select="(@_annotatedElementId, @annotatedElement, $ownerId)[.!=''][1]"/>
    <ownedComment>
      <xsl:variable name="commentPos" select="count(preceding-sibling::ownedComment) + 1"/>
      <xsl:variable name="commentSuffix"
        select="if ($commentPos > 1) then concat('-', $commentPos) else ''"/>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="concat($ownerName, '-ownedComment', $commentSuffix)"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="'uml:Comment'"/>
      <!-- body before annotatedElement per canonical property order -->
      <xsl:if test="$bodyText">
        <body><xsl:value-of select="$bodyText"/></body>
      </xsl:if>
      <xsl:if test="$annotId">
        <xsl:variable name="annotIdref">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="$annotId"/>
          </xsl:call-template>
        </xsl:variable>
        <annotatedElement xmi:idref="{$annotIdref}"/>
      </xsl:if>
    </ownedComment>
  </xsl:template>

  <!-- ============================================================
       SECTION 24: CANONICAL MODE — type / general reference
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a type or general reference as self-closing xmi:idref or href element.</xd:short>
  </xd:doc>
  <xsl:template match="type | general" mode="canonical-ref">
    <xsl:variable name="elemName" select="local-name()"/>
    <xsl:choose>
      <xsl:when test="@xmi:idref">
        <xsl:variable name="resolvedId">
          <xsl:call-template name="resolveIdref">
            <xsl:with-param name="sourceId" select="@xmi:idref"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:element name="{$elemName}">
          <xsl:attribute name="xmi:idref" select="$resolvedId"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="@href">
        <xsl:variable name="eclipsePrimBase"
          select="'http://www.eclipse.org/uml2/5.0.0/UML/PrimitiveTypes.xmi#'"/>
        <xsl:variable name="omgPrimBase"
          select="'http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#'"/>
        <xsl:variable name="isPrimHref" as="xs:boolean"
          select="starts-with(@href, $eclipsePrimBase) or
                  starts-with(@href, $omgPrimBase)"/>
        <xsl:element name="{$elemName}">
          <!-- Emit xmi:type: use source value if present; for primitive type hrefs
               always emit uml:PrimitiveType even when source omits the attribute. -->
          <xsl:choose>
            <xsl:when test="@xmi:type">
              <xsl:attribute name="xmi:type" select="@xmi:type"/>
            </xsl:when>
            <xsl:when test="$isPrimHref">
              <xsl:attribute name="xmi:type" select="'uml:PrimitiveType'"/>
            </xsl:when>
          </xsl:choose>
          <!-- Normalise primitive type hrefs to match the target namespace
               (eclipseOutput). Both Eclipse and OMG base URIs are recognised. -->
          <xsl:variable name="normHref" as="xs:string">
            <xsl:choose>
              <xsl:when test="starts-with(@href, $eclipsePrimBase)">
                <xsl:value-of select="concat($UML_PRIMITIVES_BASE,
                  substring-after(@href, $eclipsePrimBase))"/>
              </xsl:when>
              <xsl:when test="starts-with(@href, $omgPrimBase)">
                <xsl:value-of select="concat($UML_PRIMITIVES_BASE,
                  substring-after(@href, $omgPrimBase))"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@href"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:attribute name="href" select="$normHref"/>
        </xsl:element>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 25: CANONICAL MODE — lowerValue / upperValue
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits lowerValue element, applying default suppression rules.</xd:short>
    <xd:detail>Omit entirely if value is 1 or absent (default). Emit without value child if value is 0.
    Emit with value child for any other value.</xd:detail>
  </xd:doc>
  <xsl:template name="emitLowerValue">
    <xsl:param name="nsURI"     tunnel="yes"/>
    <xsl:param name="prefix"    tunnel="yes"/>
    <xsl:param name="ownerName" as="xs:string" select="concat(string(parent::*/@name), '-', string(@name))"/>
    <xsl:variable name="lv" select="lowerValue"/>
    <xsl:variable name="val" select="string($lv/@value)"/>
    <xsl:choose>
      <!-- Absent or value=1: omit entirely -->
      <xsl:when test="not($lv) or $val = '1' or $val = ''"/>
      <!-- value=0: emit element with <value>0</value> -->
      <xsl:when test="$val = '0'">
        <lowerValue>
          <xsl:call-template name="emitXmiIdUuid">
            <xsl:with-param name="node"   select="$lv"/>
            <xsl:with-param name="name"   select="concat($ownerName, '-lowerValue')"/>
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="nsURI"  select="$nsURI"/>
          </xsl:call-template>
          <xsl:attribute name="xmi:type" select="'uml:LiteralInteger'"/>
          <value>0</value>
        </lowerValue>
      </xsl:when>
      <!-- Any other value -->
      <xsl:otherwise>
        <lowerValue>
          <xsl:call-template name="emitXmiIdUuid">
            <xsl:with-param name="node"   select="$lv"/>
            <xsl:with-param name="name"   select="concat($ownerName, '-lowerValue')"/>
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="nsURI"  select="$nsURI"/>
          </xsl:call-template>
          <xsl:attribute name="xmi:type" select="'uml:LiteralInteger'"/>
          <value><xsl:value-of select="$val"/></value>
        </lowerValue>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Emits upperValue element, applying default suppression rules.</xd:short>
    <xd:detail>Omit entirely if value is 1 or absent (default).
    Normalise -1 to * for LiteralUnlimitedNatural. Emit for all other values.</xd:detail>
  </xd:doc>
  <xsl:template name="emitUpperValue">
    <xsl:param name="nsURI"     tunnel="yes"/>
    <xsl:param name="prefix"    tunnel="yes"/>
    <xsl:param name="ownerName" as="xs:string" select="concat(string(parent::*/@name), '-', string(@name))"/>
    <xsl:variable name="uv" select="upperValue"/>
    <xsl:variable name="rawVal" select="string($uv/@value)"/>
    <xsl:variable name="val" select="if ($rawVal = '-1') then '*' else $rawVal"/>
    <xsl:choose>
      <!-- Absent or value=1: omit entirely -->
      <xsl:when test="not($uv) or $val = '1' or $val = ''"/>
      <!-- Any other value (including *) -->
      <xsl:otherwise>
        <upperValue>
          <xsl:call-template name="emitXmiIdUuid">
            <xsl:with-param name="node"   select="$uv"/>
            <xsl:with-param name="name"   select="concat($ownerName, '-upperValue')"/>
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="nsURI"  select="$nsURI"/>
          </xsl:call-template>
          <xsl:attribute name="xmi:type" select="'uml:LiteralUnlimitedNatural'"/>
          <value><xsl:value-of select="$val"/></value>
        </upperValue>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 26: CANONICAL MODE — defaultValue
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a defaultValue element in canonical form.</xd:short>
    <xd:param name="ownerId"   type="xs:string">The xmi:id of the owning property.</xd:param>
    <xd:param name="ownerName" type="xs:string">The createdName of the owning property.</xd:param>
  </xd:doc>
  <xsl:template match="defaultValue" mode="canonical-value">
    <xsl:param name="ownerId"   as="xs:string"/>
    <xsl:param name="ownerName" as="xs:string"/>
    <xsl:param name="nsURI"   tunnel="yes"/>
    <xsl:param name="prefix"  tunnel="yes"/>
    <defaultValue>
      <xsl:call-template name="emitXmiIdUuid">
        <xsl:with-param name="node"   select="."/>
        <xsl:with-param name="name"   select="concat($ownerName, '-defaultValue')"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="nsURI"  select="$nsURI"/>
      </xsl:call-template>
      <xsl:attribute name="xmi:type" select="if (@xmi:type) then @xmi:type else 'uml:LiteralString'"/>
      <xsl:variable name="dvVal"
        select="(@value, *[local-name()='value'])[normalize-space(.)!=''][1]"/>
      <xsl:if test="$dvVal">
        <value><xsl:value-of select="$dvVal"/></value>
      </xsl:if>
    </defaultValue>
  </xsl:template>

  <!-- ============================================================
       SECTION 27: ID AND UUID GENERATION
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits xmi:id and xmi:uuid attributes in canonical order (id, uuid, then type is emitted by caller).</xd:short>
    <xd:detail>When generateIds=yes, generates deterministic id as prefix.createdName and
    uuid as namespaceURI#createdName. When generateIds=no, passes through source values
    with warnings for invalid characters (hyphens).</xd:detail>
    <xd:param name="node"       type="element()">The source element node.</xd:param>
    <xd:param name="name"       type="xs:string">The createdName (without prefix) for this element.</xd:param>
    <xd:param name="prefix"     type="xs:string">The namespace prefix to use in the xmi:id.</xd:param>
    <xd:param name="nsURI"      type="xs:string">The namespace URI to use in the xmi:uuid.</xd:param>
  </xd:doc>
  <xsl:template name="emitXmiIdUuid">
    <xsl:param name="node"    as="element()"/>
    <xsl:param name="name"    as="xs:string" select="''"/>
    <!-- isProxy: when true, xmi:uuid is prefixed with "proxy_" to signal
         that this element is a proxy for an external vocabulary term. -->
    <xsl:param name="isProxy" as="xs:boolean" select="false()"/>
    <xsl:param name="prefix"  as="xs:string"/>
    <xsl:param name="nsURI"   as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$generateIds = 'yes'">
        <xsl:variable name="safeName" select="replace($name, '[^A-Za-z0-9_\-\.]', '_')"/>
        <!-- Strip trailing '#' from nsURI before building uuid to avoid double '##' -->
        <xsl:variable name="baseURI"
          select="if (ends-with($nsURI, '#')) then substring($nsURI, 1, string-length($nsURI) - 1)
                  else $nsURI"/>
        <xsl:variable name="xmiId"   select="concat($prefix, '.', $safeName)"/>
        <!-- proxy_ prefix goes before the entire URI, not before the local name fragment -->
        <xsl:variable name="xmiUuid"
          select="if ($isProxy) then concat('proxy_', $baseURI, '#', $safeName)
                  else concat($baseURI, '#', $safeName)"/>
        <xsl:attribute name="xmi:id"   select="$xmiId"/>
        <xsl:attribute name="xmi:uuid" select="$xmiUuid"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Pass through source id -->
        <xsl:variable name="srcId" select="$node/@xmi:id"/>
        <xsl:if test="$srcId">
          <xsl:if test="contains($srcId, '-')">
            <xsl:message>[WARNING] xmi:id '<xsl:value-of select="$srcId"/>' contains hyphen(s) which are invalid in XML NCNames.</xsl:message>
          </xsl:if>
          <xsl:attribute name="xmi:id" select="$srcId"/>
        </xsl:if>
        <!-- Pass through source uuid -->
        <xsl:variable name="srcUuid" select="$node/@xmi:uuid"/>
        <xsl:if test="$srcUuid">
          <xsl:attribute name="xmi:uuid" select="$srcUuid"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 27b: PER-PACKAGE PREFIX RESOLUTION
       ============================================================ -->

  <xd:doc>
    <xd:short>Resolves the effective xmi:id prefix for a given package or model node.</xd:short>
    <xd:detail>Looks for a direct-child packagedElement of type uml:DataType named
    PackageInformation with an ownedAttribute named 'prefix'.
    If found, returns that prefix value. Otherwise returns the inherited $prefix tunnel param.
    The namespacePrefix parameter always takes priority over everything.</xd:detail>
    <xd:param name="packageNode" type="element()">The package or model element to inspect.</xd:param>
  </xd:doc>
  <xsl:template name="resolvePackagePrefix">
    <xsl:param name="packageNode" as="element()"/>
    <xsl:param name="prefix"      tunnel="yes"/>
    <!-- namespacePrefix parameter always wins -->
    <xsl:choose>
      <xsl:when test="$namespacePrefix != ''">
        <xsl:value-of select="$namespacePrefix"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Look for a DIRECT child DataType named PackageInformation -->
        <xsl:variable name="miNode"
          select="($packageNode/packagedElement[@xmi:type='uml:DataType']
                                               [@name='PackageInformation']
                   [ownedAttribute[@name='prefix']])[1]"/>
            <xsl:choose>
          <xsl:when test="$miNode">
            <xsl:variable name="localPrefix"
              select="normalize-space(($miNode/ownedAttribute[@name='prefix']/defaultValue/@value,
                   $miNode/ownedAttribute[@name='prefix']/defaultValue/*[local-name()='value'])[normalize-space(.)!=''][1])"/>
            <xsl:choose>
              <xsl:when test="$localPrefix != ''">
                <xsl:value-of select="$localPrefix"/>
              </xsl:when>
              <xsl:otherwise>
                <!-- DataType found but prefix value is empty — use inherited prefix -->
                <xsl:value-of select="$prefix"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <!-- No local PackageInformation — use inherited prefix -->
            <xsl:value-of select="$prefix"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Resolves the effective xmi:uuid namespace URI for a given package or model node.</xd:short>
    <xd:detail>Uses the URI attribute of the package itself if present. Otherwise falls back
    to the inherited $nsURI tunnel param. The namespaceURI parameter always takes priority.</xd:detail>
    <xd:param name="packageNode" type="element()">The package or model element to inspect.</xd:param>
  </xd:doc>
  <xsl:template name="resolvePackageNsURI">
    <xsl:param name="packageNode" as="element()"/>
    <xsl:param name="nsURI" tunnel="yes"/>
    <xsl:choose>
      <xsl:when test="$namespaceURI != ''">
        <xsl:value-of select="$namespaceURI"/>
      </xsl:when>
      <xsl:when test="normalize-space($packageNode/@URI) != ''">
        <xsl:value-of select="$packageNode/@URI"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$nsURI"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 28: NAMESPACE RESOLUTION
       ============================================================ -->

  <xd:doc>
    <xd:short>Resolves the effective namespace URI from parameter override, model URI attribute, or default.</xd:short>
    <xd:param name="modelNode" type="element()">The uml:Model element in the intermediate tree.</xd:param>
  </xd:doc>
  <xsl:template name="resolveNamespaceURI">
    <xsl:param name="modelNode" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$namespaceURI != ''">
        <xsl:value-of select="$namespaceURI"/>
      </xsl:when>
      <xsl:when test="$modelNode/@URI">
        <xsl:value-of select="$modelNode/@URI"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Resolves the effective namespace prefix from parameter, PackageInformation DataType, or model name fallback.</xd:short>
    <xd:param name="modelNode" type="element()">The uml:Model element in the intermediate tree.</xd:param>
    <xd:param name="nsURI"     type="xs:string">The resolved namespace URI.</xd:param>
  </xd:doc>
  <xsl:template name="resolveNamespacePrefix">
    <xsl:param name="modelNode" as="element()?"/>
    <xsl:param name="nsURI"     as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$namespacePrefix != ''">
        <xsl:value-of select="$namespacePrefix"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Search for PackageInformation DataType as a DIRECT child of the model only.
             Using // would find a nested package's PackageInformation and set the
             wrong root prefix, causing all packages to use that nested prefix. -->
        <xsl:variable name="miNode"
          select="($modelNode/packagedElement[@xmi:type='uml:DataType']
                   [@name='PackageInformation']
                   [ownedAttribute[@name='prefix']])[1]"/>
        <xsl:choose>
          <xsl:when test="$miNode">
            <xsl:variable name="prefixAttr"
              select="($miNode/ownedAttribute[@name='prefix']/defaultValue/@value,
                   $miNode/ownedAttribute[@name='prefix']/defaultValue/*[local-name()='value'])[normalize-space(.)!=''][1]"/>
            <xsl:choose>
              <xsl:when test="normalize-space($prefixAttr) != ''">
                <xsl:value-of select="$prefixAttr"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:message>[WARNING] PackageInformation found but prefix value is empty. Falling back to model name.</xsl:message>
                <xsl:value-of select="$modelNode/@name"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>[WARNING] No namespace prefix found (no PackageInformation DataType and no namespacePrefix parameter). Falling back to model name '<xsl:value-of select="$modelNode/@name"/>'.</xsl:message>
            <xsl:value-of select="$modelNode/@name"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 29: PRIMITIVE TYPE RESOLUTION
       ============================================================ -->

  <xd:doc>
    <xd:short>Resolves an EA or tool-specific primitive type name to the canonical UML primitive name.</xd:short>
    <xd:detail>Uses the primitiveTypeMap lookup table. Emits a warning for unmapped names and returns the name unchanged.</xd:detail>
    <xd:param name="name" type="xs:string">The source primitive type name (e.g. 'EAJava_Integer', 'int', 'Integer').</xd:param>
  </xd:doc>
  <xsl:template name="resolvePrimitiveType">
    <xsl:param name="name" as="xs:string"/>
    <xsl:variable name="mapped" select="$primitiveTypeMap/entry[@ea = $name]/@uml"/>
    <xsl:choose>
      <xsl:when test="$mapped">
        <xsl:value-of select="$mapped"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>[WARNING] Unmapped primitive type name '<xsl:value-of select="$name"/>'. Passing through unchanged.</xsl:message>
        <xsl:value-of select="$name"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 30: QUALIFIED ASSOCIATION NAME DERIVATION
       ============================================================ -->

  <xd:doc>
    <xd:short>Derives or validates a qualified association name of the form SubjectClass_assocName_ObjectClass.</xd:short>
    <xd:detail>Subject class is the type of memberEnd[2] (ownedEnd / source end).
    Object class is the type of memberEnd[1] (navigable end on target class).
    If sourceHasQualifiedNames=yes, validates against source name and warns on mismatch.</xd:detail>
    <xd:param name="assoc"      type="element()">The Association element.</xd:param>
    <xd:param name="sourceName" type="xs:string">The source association name.</xd:param>
  </xd:doc>
  <xsl:template name="deriveQualifiedAssocName">
    <xsl:param name="assoc"      as="element()"/>
    <xsl:param name="sourceName" as="xs:string"/>
    <xsl:param name="sourceRoot" tunnel="yes"/>
    <!-- memberEnd[1] = dst (navigable/object end idref) -->
    <!-- memberEnd[2] = src (ownedEnd/subject end idref, or derived from ownedEnd) -->
    <xsl:variable name="me1idref" select="$assoc/memberEnd[1]/@xmi:idref"/>
    <xsl:variable name="me2idref" select="$assoc/memberEnd[2]/@xmi:idref"/>
    <!-- Resolve object class name from memberEnd[1] type.
         key() uses $sourceRoot to search the source document explicitly,
         because this template is called from canonical-pass context
         where the current document is the intermediate tree. -->
    <xsl:variable name="objEnd"    select="key('elementById', $me1idref, $sourceRoot)"/>
    <!-- type may be a child element (EA/canonical) or unprefixed @type attribute (Eclipse) -->
    <xsl:variable name="objTypeId"
      select="($objEnd/type/@xmi:idref, $objEnd/type/@href, string($objEnd/@type))[normalize-space(.)!=''][1]"/>
    <xsl:variable name="objClass"  select="key('elementById', $objTypeId, $sourceRoot)/@name"/>
    <!-- Resolve subject class name from memberEnd[2].
         Always use key lookup to find the exact memberEnd[2] element (ownedEnd or ownedAttribute).
         The former shortcut of using ownedEnd[1] was incorrect when both ends are ownedEnds
         owned by the Association, since ownedEnd[1] is not necessarily memberEnd[2]. -->
    <xsl:variable name="srcEnd" select="key('elementById', $me2idref, $sourceRoot)"/>
    <!-- type may be a child element (EA/canonical) or unprefixed @type attribute (Eclipse) -->
    <xsl:variable name="srcTypeId"
      select="($srcEnd/type/@xmi:idref, $srcEnd/type/@href, string($srcEnd/@type))[normalize-space(.)!=''][1]"/>
    <xsl:variable name="srcClass"    select="key('elementById', $srcTypeId, $sourceRoot)/@name"/>
    <!-- Derive short name: strip existing qualification if sourceHasQualifiedNames=yes -->
    <xsl:variable name="shortName" as="xs:string">
      <xsl:choose>
        <xsl:when test="$sourceHasQualifiedNames = 'yes' and contains($sourceName, '_')">
          <!-- Extract middle part: SubjectClass_shortName_ObjectClass -->
          <xsl:variable name="parts" select="tokenize($sourceName, '_')"/>
          <xsl:value-of select="string-join($parts[position() > 1 and position() &lt; last()], '_')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$sourceName"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="derivedName"
      select="concat($srcClass, '_', $shortName, '_', $objClass)"/>
    <xsl:choose>
      <xsl:when test="$sourceHasQualifiedNames = 'yes'">
        <!-- Source already has qualified names: trust the source name.
             Attempt validation only when class names could be resolved. -->
        <xsl:if test="$srcClass != '' and $objClass != '' and $sourceName != $derivedName">
          <xsl:message>[WARNING] Qualified association name mismatch: source='<xsl:value-of select="$sourceName"/>' derived='<xsl:value-of select="$derivedName"/>'. Using source name.</xsl:message>
        </xsl:if>
        <!-- Always use the source name when sourceHasQualifiedNames=yes -->
        <xsl:value-of select="$sourceName"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Source does not have qualified names: use the derived name -->
        <xsl:value-of select="$derivedName"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 31: UTILITY TEMPLATES
       ============================================================ -->

  <xd:doc>
    <xd:short>Emits a name child element if the name is non-empty.</xd:short>
    <xd:param name="name" type="xs:string">The name string to emit.</xd:param>
  </xd:doc>
  <xsl:template name="emitNameElement">
    <xsl:param name="name" as="xs:string?"/>
    <xsl:if test="normalize-space($name) != ''">
      <name><xsl:value-of select="$name"/></name>
    </xsl:if>
  </xsl:template>

  <xd:doc>
    <xd:short>Checks for duplicate xmi:id values in the source document and emits warnings.</xd:short>
    <xd:detail>Used in pass-through mode (generateIds=no) to detect id collisions.</xd:detail>
  </xd:doc>
  <xsl:template name="checkDuplicateIds">
    <xsl:for-each-group select="//*[@xmi:id]" group-by="@xmi:id">
      <xsl:if test="count(current-group()) &gt; 1">
        <xsl:message>[WARNING] Duplicate xmi:id '<xsl:value-of select="@xmi:id"/>' found <xsl:value-of select="count(current-group())"/> times in source.</xsl:message>
      </xsl:if>
    </xsl:for-each-group>
  </xsl:template>



  <xd:doc>
    <xd:short>Derives the local createdName for a packagedElement whose name may be an IRI.</xd:short>
    <xd:detail>Proxy classes and data types representing RDF vocabulary terms have names
    that are full IRIs (e.g. http://www.w3.org/2001/XMLSchema#string). When the enclosing
    package URI is an exact prefix of the element name, that prefix is stripped to yield
    the local name (e.g. "string"). If the name looks like a URI but no package URI prefix
    matches, a warning is emitted and the name is used as-is. For non-URI names the name
    is returned unchanged.</xd:detail>
    <xd:param name="rawName" type="xs:string">The @name attribute value of the element.</xd:param>
    <xd:param name="nsURI" type="xs:string">The effective namespace URI of the enclosing package (tunnel).</xd:param>
  </xd:doc>
  <xsl:template name="deriveLocalName">
    <xsl:param name="rawName"  as="xs:string"/>
    <xsl:param name="nsURI"    tunnel="yes"/>
    <xsl:choose>
      <!-- Name is not URI-like: use as-is -->
      <xsl:when test="not(starts-with($rawName, 'http://') or
                          starts-with($rawName, 'https://'))">
        <xsl:value-of select="$rawName"/>
      </xsl:when>
      <!-- Name starts with the enclosing package URI: strip the prefix -->
      <xsl:when test="$nsURI != '' and starts-with($rawName, $nsURI)">
        <xsl:value-of select="substring-after($rawName, $nsURI)"/>
      </xsl:when>
      <!-- URI-like name but no matching package URI: warn and use as-is -->
      <xsl:otherwise>
        <xsl:message>[WARNING] Element name '<xsl:value-of select="$rawName"/>' looks like a URI but the enclosing package URI '<xsl:value-of select="$nsURI"/>' is not a prefix of it. Using name as-is.</xsl:message>
        <xsl:value-of select="$rawName"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================
       SECTION 32: CANONICAL IDREF RESOLUTION
       ============================================================ -->

  <xd:doc>
    <xd:short>Computes the effective xmi:id prefix for an element identified by its source xmi:id.</xd:short>
    <xd:detail>Looks up the element in the source document, then walks its package ancestors
    from innermost to outermost. Returns the prefix from the nearest enclosing package that
    has a PackageInformation DataType child with a non-empty prefix value.
    Falls back to the inherited $prefix tunnel param if no such ancestor is found.</xd:detail>
    <xd:param name="sourceId"   type="xs:string">The source xmi:id of the element.</xd:param>
  </xd:doc>
  <xsl:template name="computeElementPrefix">
    <xsl:param name="sourceId"   as="xs:string"/>
    <xsl:param name="sourceRoot" tunnel="yes"/>
    <xsl:param name="prefix"     tunnel="yes"/>
    <xsl:variable name="sourceNode" as="element()?"
      select="key('elementById', $sourceId, $sourceRoot)[1]"/>
    <xsl:choose>
      <xsl:when test="not($sourceNode)">
        <xsl:value-of select="$prefix"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Collect the element itself (if it is a Package/Model) plus its ancestors,
             innermost first. Including self is essential when the annotated element IS
             a package — its own PackageInformation defines its prefix, not its parent's. -->
        <xsl:variable name="pkgAncestors"
          select="($sourceNode | $sourceNode/ancestor::*)
                    [@xmi:type=('uml:Package','uml:Model') or local-name()='Model']"/>
        <!-- Walk innermost-first: use the first package that has PackageInformation -->
        <xsl:call-template name="findInnermostPrefix">
          <xsl:with-param name="packages"      select="$pkgAncestors"/>
          <xsl:with-param name="count"         select="count($pkgAncestors)"/>
          <xsl:with-param name="pos"           select="count($pkgAncestors)"/>
          <xsl:with-param name="fallback"      select="$prefix"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Finds the prefix from the innermost package ancestor that has a PackageInformation DataType.</xd:short>
    <xd:detail>Iterates from innermost (highest position) to outermost (position 1).
    Returns the first PackageInformation prefix found, or $fallback if none.</xd:detail>
    <xd:param name="packages" type="element()*">Ancestor package sequence (innermost last).</xd:param>
    <xd:param name="count"    type="xs:integer">Total count of packages.</xd:param>
    <xd:param name="pos"      type="xs:integer">Current position to check (counts down).</xd:param>
    <xd:param name="fallback" type="xs:string">Default prefix if nothing found.</xd:param>
  </xd:doc>
  <xd:doc>
    <xd:short>Finds the prefix from the innermost package ancestor that has a PackageInformation DataType.</xd:short>
    <xd:detail>Iterates the ancestor package sequence from innermost (highest index) toward
    outermost (index 1), returning the first non-empty PackageInformation prefix value found.
    Falls back to $fallback if no PackageInformation is found in any ancestor.
    Called by computeElementPrefix to resolve the canonical xmi:id prefix for any element
    regardless of the caller's own prefix context.</xd:detail>
    <xd:param name="packages" type="element()*">Ancestor package/model sequence, innermost last (ancestor::* natural order).</xd:param>
    <xd:param name="count"    type="xs:integer">Total count of elements in $packages.</xd:param>
    <xd:param name="pos"      type="xs:integer">Current position to inspect (counts down from count to 1).</xd:param>
    <xd:param name="fallback" type="xs:string">Default prefix to return when no PackageInformation is found.</xd:param>
  </xd:doc>
  <xsl:template name="findInnermostPrefix">
    <xsl:param name="packages" as="element()*"/>
    <xsl:param name="count"    as="xs:integer"/>
    <xsl:param name="pos"      as="xs:integer"/>
    <xsl:param name="fallback" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$pos lt 1">
        <!-- No package with PackageInformation found — use fallback -->
        <xsl:value-of select="$fallback"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="pkg" select="$packages[$pos]"/>
        <xsl:variable name="piPrefix"
          select="normalize-space(
            ($pkg/packagedElement[@xmi:type='uml:DataType'][@name='PackageInformation']
                /ownedAttribute[@name='prefix']/defaultValue/@value,
             $pkg/packagedElement[@xmi:type='uml:DataType'][@name='PackageInformation']
                /ownedAttribute[@name='prefix']/defaultValue/*[local-name()='value'])
            [normalize-space(.)!=''][1])"/>
        <xsl:choose>
          <xsl:when test="$piPrefix != ''">
            <xsl:value-of select="$piPrefix"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="findInnermostPrefix">
              <xsl:with-param name="packages" select="$packages"/>
              <xsl:with-param name="count"    select="$count"/>
              <xsl:with-param name="pos"      select="$pos - 1"/>
              <xsl:with-param name="fallback" select="$fallback"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>




  <xd:doc>
    <xd:short>Resolves a source xmi:id to the canonical xmi:id used in the output.</xd:short>
    <xd:detail>When generateIds=no, returns the source id unchanged.
    When generateIds=yes, looks up the element in the intermediate tree and computes
    its canonical id as prefix.createdName. Emits a warning if the element is not found.</xd:detail>
    <xd:param name="sourceId"       type="xs:string">The source xmi:id to resolve.</xd:param>
    <xd:param name="intermediateRoot" type="node()">Root of the intermediate tree.</xd:param>
    <xd:param name="prefix"         type="xs:string">The current namespace prefix.</xd:param>
  </xd:doc>
  <xsl:template name="resolveIdref">
    <xsl:param name="sourceId"        as="xs:string"/>
    <xsl:param name="intermediateRoot" tunnel="yes"/>
    <xsl:param name="prefix"           tunnel="yes"/>
    <xsl:choose>
      <xsl:when test="$generateIds != 'yes'">
        <xsl:value-of select="$sourceId"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- First try the intermediate tree; fall back to source document -->
        <xsl:variable name="target"
          select="(key('interById', $sourceId, $intermediateRoot),
                   key('elementById', $sourceId))[1]"/>
        <xsl:choose>
          <xsl:when test="not($target)">
            <xsl:message>[WARNING] Cannot resolve xmi:id '<xsl:value-of select="$sourceId"/>' in either intermediate or source tree. Using source id.</xsl:message>
            <xsl:value-of select="$sourceId"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="createdName">
              <xsl:call-template name="computeCreatedName">
                <xsl:with-param name="node" select="$target"/>
              </xsl:call-template>
            </xsl:variable>
            <!-- Compute the prefix for the TARGET element by walking its package
                 ancestors in the source document, where the full hierarchy is intact. -->
            <xsl:variable name="targetPrefix">
              <xsl:call-template name="computeElementPrefix">
                <xsl:with-param name="sourceId" select="$sourceId"/>
              </xsl:call-template>
            </xsl:variable>
            <!-- Apply the same character sanitisation as emitXmiIdUuid so that
                 xmi:idref values match the xmi:id values exactly. -->
            <xsl:variable name="safeCreatedName"
              select="replace($createdName, '[^A-Za-z0-9_\-\.]', '_')"/>
            <xsl:value-of select="concat($targetPrefix, '.', $safeCreatedName)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:short>Computes the createdName portion of a canonical xmi:id for any element.</xd:short>
    <xd:detail>Handles: packagedElement (Class/DataType/Enum/PrimitiveType/Association/Dependency/Package),
    ownedAttribute (class property), ownedEnd (association end), generalization, ownedLiteral, ownedComment.</xd:detail>
    <xd:param name="node" type="element()">The intermediate tree element to name.</xd:param>
  </xd:doc>
  <xsl:template name="computeCreatedName">
    <xsl:param name="node" as="element()"/>
    <xsl:variable name="localName" select="local-name($node)"/>
    <xsl:variable name="type"      select="$node/@xmi:type"/>
    <xsl:choose>
      <!-- Top-level named elements: Class, DataType, Enum, PrimitiveType, Package, Association, Dependency -->
      <xsl:when test="$localName = 'packagedElement' or $localName = 'uml:Model'">
        <xsl:choose>
          <xsl:when test="$type = 'uml:Association' and $qualifiedAssocNames = 'yes'">
            <!-- Qualified name for Association -->
            <xsl:variable name="rawAssocName" select="string($node/@name)"/>
            <xsl:variable name="assocPkgURI"
              select="string(($node/ancestor-or-self::*/parent::*[@URI])[last()]/@URI)"/>
            <xsl:variable name="strippedAssocName"
              select="if ($assocPkgURI != '' and starts-with($rawAssocName, $assocPkgURI))
                      then substring-after($rawAssocName, $assocPkgURI)
                      else $rawAssocName"/>
            <xsl:call-template name="deriveQualifiedAssocName">
              <xsl:with-param name="assoc"      select="$node"/>
              <xsl:with-param name="sourceName" select="$strippedAssocName"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="$type = 'uml:Abstraction' and $qualifiedAssocNames = 'yes'">
            <!-- Qualified name for Abstraction (uses @client/@supplier directly) -->
            <xsl:variable name="rawAbsName" select="string($node/@name)"/>
            <xsl:variable name="absPkgURI"
              select="string(($node/ancestor-or-self::*/parent::*[@URI])[last()]/@URI)"/>
            <xsl:variable name="strippedAbsName"
              select="if ($absPkgURI != '' and starts-with($rawAbsName, $absPkgURI))
                      then substring-after($rawAbsName, $absPkgURI)
                      else $rawAbsName"/>
            <xsl:call-template name="deriveQualifiedAbstractionName">
              <xsl:with-param name="sourceName"  select="$strippedAbsName"/>
              <xsl:with-param name="clientId"    select="string($node/@client)"/>
              <xsl:with-param name="supplierId"  select="string($node/@supplier)"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="$type = 'uml:Dependency' and $qualifiedAssocNames = 'yes'">
            <!-- Qualified name for Dependency — same endpoint logic as Abstraction -->
            <xsl:variable name="rawDepName" select="string($node/@name)"/>
            <xsl:variable name="depPkgURI"
              select="string(($node/ancestor-or-self::*/parent::*[@URI])[last()]/@URI)"/>
            <xsl:variable name="strippedDepName"
              select="if ($depPkgURI != '' and starts-with($rawDepName, $depPkgURI))
                      then substring-after($rawDepName, $depPkgURI)
                      else $rawDepName"/>
            <xsl:call-template name="deriveQualifiedAbstractionName">
              <xsl:with-param name="sourceName"  select="$strippedDepName"/>
              <xsl:with-param name="clientId"    select="string($node/@client)"/>
              <xsl:with-param name="supplierId"  select="string($node/@supplier)"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <!-- Strip enclosing package URI prefix from IRI-style element names -->
            <xsl:variable name="rawName" select="string($node/@name)"/>
            <xsl:variable name="pkgURI"
              select="string(($node/ancestor-or-self::*/parent::*[@URI])[last()]/@URI)"/>
            <xsl:choose>
              <xsl:when test="$pkgURI != '' and starts-with($rawName, $pkgURI)">
                <xsl:value-of select="substring-after($rawName, $pkgURI)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="$rawName"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- ownedAttribute (class property) -->
      <xsl:when test="$localName = 'ownedAttribute'">
        <xsl:variable name="parentName" select="$node/parent::*/@name"/>
        <xsl:choose>
          <xsl:when test="normalize-space($node/@name) != ''">
            <xsl:value-of select="concat($parentName, '-', $node/@name)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat($parentName, '-ownedAttribute-',
              count($node/preceding-sibling::ownedAttribute) + 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- ownedEnd: use type class name for disambiguation -->
      <xsl:when test="$localName = 'ownedEnd'">
        <xsl:variable name="oeTypeId"   select="$node/type/@xmi:idref"/>
        <xsl:variable name="oeTypeName" select="key('elementById', $oeTypeId)/@name"/>
        <xsl:choose>
          <xsl:when test="normalize-space($oeTypeName) != ''">
            <xsl:value-of select="concat($node/parent::*/@name, '-ownedEnd-', $oeTypeName)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat($node/parent::*/@name, '-ownedEnd-',
              count($node/preceding-sibling::ownedEnd) + 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- generalization -->
      <xsl:when test="$localName = 'generalization'">
        <xsl:value-of select="concat($node/parent::*/@name, '-generalization')"/>
      </xsl:when>
      <!-- ownedLiteral -->
      <xsl:when test="$localName = 'ownedLiteral'">
        <xsl:value-of select="concat($node/parent::*/@name, '-', $node/@name)"/>
      </xsl:when>
      <!-- ownedComment -->
      <xsl:when test="$localName = 'ownedComment'">
        <xsl:variable name="pos" select="count($node/preceding-sibling::ownedComment) + 1"/>
        <xsl:variable name="suffix" select="if ($pos > 1) then concat('-', $pos) else ''"/>
        <xsl:value-of select="concat($node/parent::*/@name, '-ownedComment', $suffix)"/>
      </xsl:when>
      <!-- lowerValue / upperValue / defaultValue -->
      <xsl:when test="$localName = ('lowerValue', 'upperValue', 'defaultValue')">
        <xsl:variable name="propName">
          <xsl:call-template name="computeCreatedName">
            <xsl:with-param name="node" select="$node/parent::*"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="concat($propName, '-', $localName)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="($node/@name, $localName)[normalize-space(.)!=''][1]"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
