.pragma library

function colorChoice(value) {
    return value === "theme" || value === "foreground" || value === "urgent"
        || (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value));
}

function valid(key, value) {
    if (["showChart", "showHighlights", "showYearInsights", "motion"].indexOf(key) !== -1)
        return typeof value === "boolean";
    if (key === "chartSamples")
        return [7, 14, 30, 60].indexOf(value) !== -1;
    if (key === "heroColor" || key === "insightColor")
        return colorChoice(value);
    return false;
}

function preferences(raw) {
    var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    var result = {
        showChart: true, showHighlights: true, showYearInsights: true, motion: true,
        chartSamples: 14, heroColor: "theme", insightColor: "theme"
    };
    for (var key in result)
        if (Object.prototype.hasOwnProperty.call(source, key) && valid(key, source[key]))
            result[key] = source[key];
    return result;
}

function tint(choice, accent, foreground, urgent) {
    if (choice === "foreground") return foreground;
    if (choice === "urgent") return urgent;
    return colorChoice(choice) && choice !== "theme" ? choice : accent;
}
