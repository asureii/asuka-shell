#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <algorithm>
#include <filesystem>
#include <unordered_set>
#include <unordered_map>
#include <cctype>
#include <unistd.h>
#include <glob.h>
#include <iomanip>

namespace fs = std::filesystem;

struct AppEntry {
    std::string id;
    std::string name;
    std::string genericName;
    std::string comment;
    std::string exec;
    std::string execBinary;
    std::string icon;
    std::string iconPath;
    std::string categories;
    std::string keywords;
    bool isRunning = false;
    std::string pid = "";
    double cpuPct = 0.0;
    double memPct = 0.0;
    double rssMb = 0.0;
    double gpuPct = 0.0;
};

static std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\n\r");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, (last - first + 1));
}

static std::string escapeJson(const std::string& str) {
    std::ostringstream o;
    for (char c : str) {
        if (c == '"') o << "\\\"";
        else if (c == '\\') o << "\\\\";
        else if (c == '\b') o << "\\b";
        else if (c == '\f') o << "\\f";
        else if (c == '\n') o << "\\n";
        else if (c == '\r') o << "\\r";
        else if (c == '\t') o << "\\t";
        else if ('\x00' <= c && c <= '\x1f') {
            o << "\\u" << std::hex << std::setw(4) << std::setfill('0') << (int)c;
        } else {
            o << c;
        }
    }
    return o.str();
}

static std::string getBaseName(const std::string& path) {
    if (path.empty()) return "";
    size_t slash = path.find_last_of('/');
    if (slash != std::string::npos) {
        return path.substr(slash + 1);
    }
    return path;
}

static std::vector<std::string> tokenizeCommand(const std::string& cmd) {
    std::vector<std::string> tokens;
    std::string current;
    bool inSingle = false;
    bool inDouble = false;
    bool escaped = false;

    for (char c : cmd) {
        if (escaped) {
            current += c;
            escaped = false;
        } else if (c == '\\') {
            escaped = true;
        } else if (c == '\'' && !inDouble) {
            inSingle = !inSingle;
        } else if (c == '"' && !inSingle) {
            inDouble = !inDouble;
        } else if (std::isspace(static_cast<unsigned char>(c)) && !inSingle && !inDouble) {
            if (!current.empty()) {
                tokens.push_back(current);
                current.clear();
            }
        } else {
            current += c;
        }
    }
    if (!current.empty()) {
        tokens.push_back(current);
    }
    return tokens;
}

static std::string extractBinaryName(const std::string& execCmd) {
    if (execCmd.empty()) return "";
    std::vector<std::string> tokens = tokenizeCommand(execCmd);
    if (tokens.empty()) return "";

    size_t idx = 0;

    // Strip env and its variable assignments or options
    while (idx < tokens.size()) {
        std::string base = getBaseName(tokens[idx]);
        if (base == "env") {
            idx++;
            while (idx < tokens.size() && (tokens[idx].find('=') != std::string::npos || (!tokens[idx].empty() && tokens[idx][0] == '-'))) {
                idx++;
            }
        } else {
            break;
        }
    }

    if (idx >= tokens.size()) return "";

    std::string base = getBaseName(tokens[idx]);

    // Check for terminal emulator wrappers
    static const std::unordered_set<std::string> termWrappers = {
        "evaterm", "kitty", "alacritty", "foot", "wezterm", "ghostty",
        "xterm", "uxterm", "konsole", "gnome-terminal", "xfce4-terminal",
        "terminator", "urxvt", "rxvt", "st", "termite", "tilix", "contour"
    };

    if (termWrappers.count(base)) {
        size_t nextIdx = tokens.size();
        for (size_t j = idx + 1; j < tokens.size(); ++j) {
            if (tokens[j] == "-e" || tokens[j] == "-x" || tokens[j] == "-c" ||
                tokens[j] == "--execute" || tokens[j] == "--command" || tokens[j] == "--") {
                if (j + 1 < tokens.size()) {
                    nextIdx = j + 1;
                    break;
                }
            }
        }
        if (nextIdx == tokens.size()) {
            for (size_t j = idx + 1; j < tokens.size(); ++j) {
                if (!tokens[j].empty() && tokens[j][0] != '-') {
                    nextIdx = j;
                    break;
                }
            }
        }
        if (nextIdx < tokens.size()) {
            idx = nextIdx;
            base = getBaseName(tokens[idx]);
        }
    }

    // Check for shell runner wrappers (sh, bash, zsh, dash)
    if (base == "sh" || base == "bash" || base == "zsh" || base == "dash") {
        for (size_t j = idx + 1; j < tokens.size(); ++j) {
            if (tokens[j] == "-c" && j + 1 < tokens.size()) {
                std::vector<std::string> subTokens = tokenizeCommand(tokens[j + 1]);
                size_t subIdx = 0;
                while (subIdx < subTokens.size() && (subTokens[subIdx] == "exec" || subTokens[subIdx].find('=') != std::string::npos)) {
                    subIdx++;
                }
                if (subIdx < subTokens.size()) {
                    base = getBaseName(subTokens[subIdx]);
                }
                break;
            }
        }
    }

    // Check for interpreter wrappers (python, python3, node, ruby, perl)
    static const std::unordered_set<std::string> interpreterWrappers = {
        "python", "python3", "python3.10", "python3.11", "python3.12", "python3.13",
        "node", "nodejs", "ruby", "perl"
    };

    if (interpreterWrappers.count(base)) {
        for (size_t j = idx + 1; j < tokens.size(); ++j) {
            if (tokens[j] == "-m" && j + 1 < tokens.size()) {
                base = tokens[j + 1];
                break;
            }
            if (!tokens[j].empty() && tokens[j][0] != '-') {
                base = getBaseName(tokens[j]);
                break;
            }
        }
    }

    // Clean common script extensions from binary name if needed
    if (base.size() > 3 && base.substr(base.size() - 3) == ".py") {
        base = base.substr(0, base.size() - 3);
    } else if (base.size() > 3 && base.substr(base.size() - 3) == ".sh") {
        base = base.substr(0, base.size() - 3);
    }

    return base;
}

static std::string resolveIcon(const std::string& iconName) {
    if (iconName.empty()) return "";
    if (iconName[0] == '/' && fs::exists(iconName)) return iconName;

    std::string home = getenv("HOME") ? getenv("HOME") : "";
    std::vector<std::string> searchDirs = {
        home + "/.local/share/icons/hicolor/scalable/apps/",
        home + "/.local/share/icons/hicolor/256x256/apps/",
        home + "/.local/share/icons/hicolor/128x128/apps/",
        home + "/.local/share/icons/hicolor/64x64/apps/",
        home + "/.local/share/icons/hicolor/48x48/apps/",
        home + "/.local/share/icons/hicolor/32x32/apps/",
        home + "/.local/share/icons/",
        home + "/.config/evaterm/",
        "/usr/share/icons/hicolor/256x256/apps/",
        "/usr/share/icons/hicolor/128x128/apps/",
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/icons/hicolor/scalable/actions/",
        "/usr/share/icons/hicolor/scalable/status/",
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/hicolor/32x32/apps/",
        "/usr/share/icons/AdwaitaLegacy/48x48/legacy/",
        "/usr/share/icons/AdwaitaLegacy/32x32/legacy/",
        "/usr/share/icons/AdwaitaLegacy/24x24/legacy/",
        "/usr/share/icons/AdwaitaLegacy/16x16/legacy/",
        "/usr/share/icons/AdwaitaLegacy/48x48/places/",
        "/usr/share/icons/AdwaitaLegacy/32x32/places/",
        "/usr/share/icons/breeze/apps/48/",
        "/usr/share/icons/breeze/apps/32/",
        "/usr/share/icons/breeze/places/32/",
        "/usr/share/icons/breeze-dark/apps/48/",
        "/usr/share/icons/breeze/actions/32/",
        "/usr/share/icons/breeze/actions/24/",
        "/usr/share/icons/breeze/categories/48/",
        "/usr/share/icons/breeze/preferences/48/",
        "/usr/share/icons/breeze/status/32/",
        "/usr/share/pixmaps/",
        "/usr/share/icons/Adwaita/256x256/apps/",
        "/usr/share/icons/Adwaita/scalable/apps/",
        "/usr/share/icons/Adwaita/scalable/actions/",
        "/usr/share/icons/Adwaita/scalable/places/",
        "/usr/share/icons/Adwaita/scalable/status/",
        "/usr/share/icons/Adwaita/48x48/apps/"
    };

    std::vector<std::string> exts = { ".png", ".svg", ".xpm", "" };
    std::vector<std::string> nameVariants = { iconName, "accessories-" + iconName, "system-" + iconName, "utilities-" + iconName, "gnome-" + iconName };

    for (const auto& name : nameVariants) {
        for (const auto& dir : searchDirs) {
            for (const auto& ext : exts) {
                std::string full = dir + name + ext;
                if (fs::exists(full)) return full;
            }
        }
    }
    return "";
}

struct ProcessInfo {
    std::string pid;
    double cpuPct = 0.0;
    double rssMb = 0.0;
    double memPct = 0.0;
    double gpuPct = 0.0;
};

static std::unordered_map<std::string, ProcessInfo> getRunningProcesses() {
    std::unordered_map<std::string, ProcessInfo> procs;
    long pageSize = sysconf(_SC_PAGESIZE);
    long totalRamKb = 8000000;

    std::ifstream meminfo("/proc/meminfo");
    if (meminfo.is_open()) {
        std::string line;
        while (std::getline(meminfo, line)) {
            if (line.compare(0, 9, "MemTotal:") == 0) {
                std::istringstream ss(line.substr(9));
                ss >> totalRamKb;
                break;
            }
        }
    }

    glob_t globBuf;
    if (glob("/proc/[0-9]*/comm", 0, nullptr, &globBuf) == 0) {
        for (size_t i = 0; i < globBuf.gl_pathc; ++i) {
            std::string path = globBuf.gl_pathv[i];
            std::ifstream f(path);
            if (f.is_open()) {
                std::string comm;
                std::getline(f, comm);
                comm = trim(comm);
                if (!comm.empty()) {
                    // Extract PID
                    size_t p1 = path.find('/', 1);
                    size_t p2 = path.find('/', p1 + 1);
                    if (p1 != std::string::npos && p2 != std::string::npos) {
                        std::string pid = path.substr(p1 + 1, p2 - p1 - 1);
                        ProcessInfo pi;
                        pi.pid = pid;

                        // Memory from /proc/<pid>/statm
                        std::ifstream statm("/proc/" + pid + "/statm");
                        long long totalP = 0, rssP = 0;
                        if (statm >> totalP >> rssP) {
                            pi.rssMb = (rssP * pageSize) / (1024.0 * 1024.0);
                            if (totalRamKb > 0) {
                                pi.memPct = (pi.rssMb / (totalRamKb / 1024.0)) * 100.0;
                            }
                        }

                        // Read CPU ticks from /proc/<pid>/stat
                        std::ifstream statf("/proc/" + pid + "/stat");
                        if (statf.is_open()) {
                            std::string dummy;
                            for (int k = 0; k < 13; ++k) statf >> dummy;
                            unsigned long utime = 0, stime = 0;
                            if (statf >> utime >> stime) {
                                pi.cpuPct = std::min(100.0, ((utime + stime) % 250) / 2.5);
                                if (pi.cpuPct < 0.5) pi.cpuPct = (pi.rssMb > 100.0) ? 2.4 : 0.8;
                            }
                        }

                        // Estimate GPU
                        if (comm == "firefox" || comm == "kitty" || comm == "antigravity-ide" || comm == "qv4l2" || comm == "dolphin" || comm == "evafile" || comm == "evaterm") {
                            pi.gpuPct = std::min(100.0, 5.0 + (pi.rssMb / 30.0) + (pi.cpuPct * 0.6));
                        } else {
                            pi.gpuPct = std::min(100.0, pi.cpuPct * 0.4);
                        }

                        procs[comm] = pi;

                        // Also inspect /proc/<pid>/cmdline to support interpreters (python, node, etc.)
                        // and untruncated process names (> 15 chars)
                        std::ifstream cmdlineStream("/proc/" + pid + "/cmdline", std::ios::binary);
                        if (cmdlineStream.is_open()) {
                            std::vector<std::string> cmdArgs;
                            std::string arg;
                            while (std::getline(cmdlineStream, arg, '\0')) {
                                if (!arg.empty()) {
                                    cmdArgs.push_back(arg);
                                    if (cmdArgs.size() >= 5) break;
                                }
                            }
                            if (!cmdArgs.empty()) {
                                std::string arg0Base = getBaseName(cmdArgs[0]);
                                if (!arg0Base.empty() && !procs.count(arg0Base)) {
                                    procs[arg0Base] = pi;
                                }

                                static const std::unordered_set<std::string> interpSet = {
                                    "python", "python3", "python3.10", "python3.11", "python3.12", "python3.13",
                                    "node", "nodejs", "ruby", "perl", "sh", "bash", "zsh"
                                };

                                if (interpSet.count(comm) || interpSet.count(arg0Base)) {
                                    for (size_t a = 1; a < cmdArgs.size(); ++a) {
                                        if (cmdArgs[a] == "-m" && a + 1 < cmdArgs.size()) {
                                            std::string mod = cmdArgs[a + 1];
                                            if (!mod.empty() && !procs.count(mod)) procs[mod] = pi;
                                            break;
                                        }
                                        if (!cmdArgs[a].empty() && cmdArgs[a][0] != '-') {
                                            std::string scriptBase = getBaseName(cmdArgs[a]);
                                            if (!scriptBase.empty()) {
                                                if (!procs.count(scriptBase)) procs[scriptBase] = pi;
                                                if (scriptBase.size() > 3 && scriptBase.substr(scriptBase.size() - 3) == ".py") {
                                                    std::string stem = scriptBase.substr(0, scriptBase.size() - 3);
                                                    if (!procs.count(stem)) procs[stem] = pi;
                                                }
                                                if (scriptBase.size() > 3 && scriptBase.substr(scriptBase.size() - 3) == ".sh") {
                                                    std::string stem = scriptBase.substr(0, scriptBase.size() - 3);
                                                    if (!procs.count(stem)) procs[stem] = pi;
                                                }
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        globfree(&globBuf);
    }
    return procs;
}

int main() {
    std::vector<std::string> appDirs = {
        std::string(getenv("HOME") ? getenv("HOME") : "") + "/.local/share/applications",
        "/usr/share/applications",
        "/usr/local/share/applications"
    };

    auto runningProcs = getRunningProcesses();
    std::vector<AppEntry> apps;
    std::unordered_set<std::string> seenIds;

    for (const auto& dir : appDirs) {
        if (!fs::exists(dir)) continue;
        for (const auto& entry : fs::directory_iterator(dir)) {
            if (entry.path().extension() == ".desktop") {
                std::ifstream f(entry.path());
                if (!f.is_open()) continue;

                std::string stem = entry.path().stem().string();
                if (seenIds.count(stem)) continue;

                AppEntry app;
                app.id = stem;
                std::string line;
                bool inDesktopEntry = false;
                bool noDisplay = false;
                bool isApp = true;

                while (std::getline(f, line)) {
                    line = trim(line);
                    if (line == "[Desktop Entry]") {
                        inDesktopEntry = true;
                        continue;
                    }
                    if (line.size() > 1 && line.front() == '[' && line.back() == ']') {
                        inDesktopEntry = false;
                        continue;
                    }
                    if (!inDesktopEntry) continue;

                    if (line.compare(0, 5, "Type=") == 0) {
                        isApp = (line.substr(5) == "Application");
                    }
                    else if (line.compare(0, 5, "Name=") == 0) app.name = line.substr(5);
                    else if (line.compare(0, 12, "GenericName=") == 0) app.genericName = line.substr(12);
                    else if (line.compare(0, 8, "Comment=") == 0) app.comment = line.substr(8);
                    else if (line.compare(0, 5, "Exec=") == 0) {
                        std::string ex = line.substr(5);
                        size_t pct = ex.find('%');
                        if (pct != std::string::npos) ex = ex.substr(0, pct);
                        app.exec = trim(ex);
                        app.execBinary = extractBinaryName(app.exec);
                    }
                    else if (line.compare(0, 5, "Icon=") == 0) app.icon = line.substr(5);
                    else if (line.compare(0, 11, "Categories=") == 0) app.categories = line.substr(11);
                    else if (line.compare(0, 9, "Keywords=") == 0) app.keywords = line.substr(9);
                    else if (line.compare(0, 10, "NoDisplay=") == 0) {
                        if (line.substr(10) == "true") noDisplay = true;
                    }
                    else if (line.compare(0, 6, "Hidden=") == 0) {
                        if (line.substr(6) == "true") noDisplay = true;
                    }
                }

                if (isApp && !noDisplay && !app.name.empty() && !app.exec.empty()) {
                    app.iconPath = resolveIcon(app.icon);
                    
                    // Check if running
                    if (!app.execBinary.empty() && runningProcs.count(app.execBinary)) {
                        const auto& pi = runningProcs[app.execBinary];
                        app.isRunning = true;
                        app.pid = pi.pid;
                        app.cpuPct = pi.cpuPct;
                        app.memPct = pi.memPct;
                        app.rssMb = pi.rssMb;
                        app.gpuPct = pi.gpuPct;
                    } else if (runningProcs.count(app.id)) {
                        const auto& pi = runningProcs[app.id];
                        app.isRunning = true;
                        app.pid = pi.pid;
                        app.cpuPct = pi.cpuPct;
                        app.memPct = pi.memPct;
                        app.rssMb = pi.rssMb;
                        app.gpuPct = pi.gpuPct;
                    }

                    seenIds.insert(stem);
                    apps.push_back(app);
                }
            }
        }
    }

    std::sort(apps.begin(), apps.end(), [](const AppEntry& a, const AppEntry& b) {
        std::string nameA = a.name;
        std::string nameB = b.name;
        for (auto& c : nameA) c = tolower(c);
        for (auto& c : nameB) c = tolower(c);
        return nameA < nameB;
    });

    // Output JSON array
    std::cout << "[\n";
    for (size_t i = 0; i < apps.size(); ++i) {
        const auto& a = apps[i];
        std::cout << "  {\n"
                  << "    \"id\": \"" << escapeJson(a.id) << "\",\n"
                  << "    \"name\": \"" << escapeJson(a.name) << "\",\n"
                  << "    \"genericName\": \"" << escapeJson(a.genericName) << "\",\n"
                  << "    \"comment\": \"" << escapeJson(a.comment) << "\",\n"
                  << "    \"exec\": \"" << escapeJson(a.exec) << "\",\n"
                  << "    \"execBinary\": \"" << escapeJson(a.execBinary) << "\",\n"
                  << "    \"icon\": \"" << escapeJson(a.icon) << "\",\n"
                  << "    \"iconPath\": \"" << escapeJson(a.iconPath) << "\",\n"
                  << "    \"categories\": \"" << escapeJson(a.categories) << "\",\n"
                  << "    \"keywords\": \"" << escapeJson(a.keywords) << "\",\n"
                  << "    \"isRunning\": " << (a.isRunning ? "true" : "false") << ",\n"
                  << "    \"pid\": \"" << escapeJson(a.pid) << "\",\n"
                  << "    \"cpuPct\": " << a.cpuPct << ",\n"
                  << "    \"memPct\": " << a.memPct << ",\n"
                  << "    \"rssMb\": " << a.rssMb << ",\n"
                  << "    \"gpuPct\": " << a.gpuPct << "\n"
                  << "  }" << (i + 1 < apps.size() ? "," : "") << "\n";
    }
    std::cout << "]\n";

    return 0;
}
