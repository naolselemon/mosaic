.pragma library

function glyph(name, rightToLeft) {
    switch (name) {
    case "search": return "\uf002";
    case "refresh": return "\uf021";
    case "download": return "\uf019";
    case "stop": return "\uf04d";
    case "close": return "\uf00d";
    case "back": return rightToLeft ? "\uf061" : "\uf060";
    case "triangle-back": return rightToLeft ? "\uf0da" : "\uf0d9";
    case "triangle-up": return "\uf0d8";
    case "triangle-down": return "\uf0d7";
    case "folder": return "\uf07c";
    case "copy": return "\uf0c5";
    case "deep": return "\uf0e7";
    case "settings": return "\uf013";
    case "history": return "\uf1da";
    case "calendar": return "\uf073";
    case "chart": return "\uf080";
    case "package": return "\uf187";
    case "alert": return "\uf0f3";
    case "link": return "\uf0c1";
    case "down": return "\uf078";
    case "next": return rightToLeft ? "\uf053" : "\uf054";
    case "cache": return "\uf1b2";
    case "growth": return "\uf062";
    case "shrink": return "\uf063";
    case "leftovers": return "\uf12a";
    case "apps": return "\uf00a";
    case "check": return "\uf00c";
    case "add": return "\uf067";
    case "edit": return "\uf040";
    case "scan": return "\uf1e5";
    case "keyboard": return "\uf11c";
    case "config": return "\uf1de";
    case "data": return "\uf1c0";
    case "bug": return "\uf188";
    case "idea": return "\uf0eb";
    case "contribute": return "\uf126";
    case "star": return "\uf005";
    case "external": return "\uf08e";
    default: return "\uf05a";
    }
}
