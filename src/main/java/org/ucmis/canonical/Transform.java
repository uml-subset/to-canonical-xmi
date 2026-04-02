package org.ucmis.canonical;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Entry point for the to-canonical-xmi transform.
 *
 * Wraps Saxon HE's Transform class. The stylesheet (to-canonical-xmi.xslt)
 * is bundled as a classpath resource so no external file path is required.
 * All other Saxon command-line arguments are passed through unchanged.
 *
 * Usage (fat JAR):
 *   java -jar to-canonical-xmi-1.0.0.jar -s:input.xmi -o:output.xmi [param=value ...]
 *
 * Usage (Maven wrapper):
 *   ./mvnw compile exec:java -Dxslt.input=input.xmi -Dxslt.output=output.xmi [-Dxslt.param=value ...]
 *
 * Parameters:
 *   generateIds                yes|no (default: yes)
 *   namespaceURI               namespace URI for xmi:uuid generation
 *   namespacePrefix            prefix for xmi:id generation
 *   qualifiedAssocNames        yes|no (default: yes)
 *   sourceHasQualifiedNames    yes|no (default: no)
 *   sourcePackageName          promote named package to uml:Model root
 *   input                      ea|eclipse|generic (default: auto-detect)
 *   eclipseOutput              yes|no (default: no)
 *   profilePrefix              namespace prefix of external UML profile
 *   profileNamespaceURI        override URI for external profile
 */
public class Transform {

    private static final String STYLESHEET = "to-canonical-xmi.xslt";
    private static final String VERSION    = "1.0.0";

    public static void main(String[] args) throws Exception {
        if (args.length == 0 || hasFlag(args, "--help", "-help", "-h", "-?")) {
            printUsage();
            System.exit(0);
        }

        Path stylesheet = extractStylesheet();
        try {
            List<String> saxonArgs = new ArrayList<>();
            saxonArgs.add("-xsl:" + stylesheet.toAbsolutePath());
            saxonArgs.addAll(Arrays.asList(args));
            net.sf.saxon.Transform.main(saxonArgs.toArray(new String[0]));
        } finally {
            Files.deleteIfExists(stylesheet);
        }
    }

    private static Path extractStylesheet() throws IOException {
        URL resource = Transform.class.getClassLoader().getResource(STYLESHEET);
        if (resource == null) {
            throw new IllegalStateException(
                "Bundled stylesheet not found: " + STYLESHEET +
                "\nThe JAR may be corrupt. Re-download to-canonical-xmi-" + VERSION + ".jar");
        }
        Path tmp = Files.createTempFile("to-canonical-xmi-", ".xslt");
        try (InputStream in = resource.openStream()) {
            Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
        }
        return tmp;
    }

    private static boolean hasFlag(String[] args, String... flags) {
        List<String> flagList = Arrays.asList(flags);
        return Arrays.stream(args).anyMatch(flagList::contains);
    }

    private static void printUsage() {
        System.out.println("to-canonical-xmi " + VERSION);
        System.out.println("Transforms EA XMI and Eclipse UML XMI to Canonical XMI (UCMIS)");
        System.out.println();
        System.out.println("Usage:");
        System.out.println("  java -jar to-canonical-xmi-" + VERSION + ".jar \\");
        System.out.println("    -s:<input.xmi> -o:<output.xmi> [parameter=value ...]");
        System.out.println();
        System.out.println("Parameters:");
        System.out.println("  generateIds=yes|no              default: yes");
        System.out.println("  namespaceURI=<uri>              namespace URI for xmi:uuid");
        System.out.println("  namespacePrefix=<prefix>        prefix for xmi:id");
        System.out.println("  qualifiedAssocNames=yes|no      default: yes");
        System.out.println("  sourceHasQualifiedNames=yes|no  default: no");
        System.out.println("  sourcePackageName=<name>        promote named package to uml:Model root");
        System.out.println("  input=ea|eclipse|generic        override input flavour detection");
        System.out.println("  eclipseOutput=yes|no            Eclipse UML namespace in output, default: no");
        System.out.println("  profilePrefix=<prefix>          namespace prefix of external UML profile");
        System.out.println("  profileNamespaceURI=<uri>       override URI for external profile");
        System.out.println();
        System.out.println("Examples:");
        System.out.println("  java -jar to-canonical-xmi-" + VERSION + ".jar \\");
        System.out.println("    -s:model.xmi -o:canonical.xmi \\");
        System.out.println("    namespacePrefix=LIB \"namespaceURI=http://example.org/lib\"");
        System.out.println();
        System.out.println("  java -jar to-canonical-xmi-" + VERSION + ".jar \\");
        System.out.println("    -s:model.uml -o:canonical.xmi input=eclipse \\");
        System.out.println("    namespacePrefix=LIB \"namespaceURI=http://example.org/lib\"");
    }
}
