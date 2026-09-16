#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cstring>
#include <unistd.h>
#include <glob.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>

struct CpuSnapshot {
    unsigned long long user = 0;
    unsigned long long nice = 0;
    unsigned long long system = 0;
    unsigned long long idle = 0;
    unsigned long long iowait = 0;
    unsigned long long irq = 0;
    unsigned long long softirq = 0;
    unsigned long long steal = 0;

    unsigned long long getTotal() const {
        return user + nice + system + idle + iowait + irq + softirq + steal;
    }

    unsigned long long getIdle() const {
        return idle + iowait;
    }
};

static std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\n\r");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, (last - first + 1));
}

static std::string readFile(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) return "";
    std::stringstream buffer;
    buffer << file.rdbuf();
    return trim(buffer.str());
}

static std::vector<CpuSnapshot> readProcStat() {
    std::vector<CpuSnapshot> snapshots;
    std::ifstream statFile("/proc/stat");
    if (!statFile.is_open()) return snapshots;

    std::string line;
    while (std::getline(statFile, line)) {
        if (line.compare(0, 3, "cpu") == 0) {
            std::istringstream ss(line);
            std::string cpuLabel;
            CpuSnapshot snap;
            ss >> cpuLabel >> snap.user >> snap.nice >> snap.system >> snap.idle
               >> snap.iowait >> snap.irq >> snap.softirq >> snap.steal;
            snapshots.push_back(snap);
        }
    }
    return snapshots;
}

int main() {
    // 1. Hostname & Kernel Version
    struct utsname uts;
    std::string hostName = "NERV-NODE";
    std::string kernelVer = "Unknown";
    if (uname(&uts) == 0) {
        hostName = uts.nodename;
        kernelVer = uts.release;
    }

    // 2. CPU Model Name
    std::string cpuModel = "Generic x86_64 Processor";
    std::ifstream cpuInfo("/proc/cpuinfo");
    if (cpuInfo.is_open()) {
        std::string line;
        while (std::getline(cpuInfo, line)) {
            if (line.find("model name") != std::string::npos) {
                size_t colon = line.find(':');
                if (colon != std::string::npos) {
                    cpuModel = trim(line.substr(colon + 1));
                    break;
                }
            }
        }
    }

    // 3. Motherboard Identification
    std::string boardVendor = readFile("/sys/class/dmi/id/sys_vendor");
    std::string boardProduct = readFile("/sys/class/dmi/id/product_name");
    std::string boardName = "NERV Tactical Motherboard";
    if (!boardVendor.empty() || !boardProduct.empty()) {
        boardName = trim(boardVendor + " " + boardProduct);
    }

    // 4. Memory & Swap from /proc/meminfo
    unsigned long long memTotal = 0, memAvailable = 0;
    unsigned long long swapTotal = 0, swapFree = 0;
    std::ifstream memInfo("/proc/meminfo");
    if (memInfo.is_open()) {
        std::string key;
        unsigned long long val;
        std::string unit;
        while (memInfo >> key >> val >> unit) {
            if (key == "MemTotal:") memTotal = val;
            else if (key == "MemAvailable:") memAvailable = val;
            else if (key == "SwapTotal:") swapTotal = val;
            else if (key == "SwapFree:") swapFree = val;
        }
    }

    unsigned long long memUsed = (memTotal > memAvailable) ? (memTotal - memAvailable) : 0;
    int ramPct = (memTotal > 0) ? static_cast<int>((memUsed * 100) / memTotal) : 0;
    double ramUsedGb = static_cast<double>(memUsed) / 1048576.0;
    double ramTotalGb = static_cast<double>(memTotal) / 1048576.0;

    unsigned long long swapUsed = (swapTotal > swapFree) ? (swapTotal - swapFree) : 0;
    int swapPct = (swapTotal > 0) ? static_cast<int>((swapUsed * 100) / swapTotal) : 0;
    double swapUsedGb = static_cast<double>(swapUsed) / 1048576.0;
    double swapTotalGb = static_cast<double>(swapTotal) / 1048576.0;

    // 5. Filesystem Partitions (Root & User /home)
    struct statvfs rfs, hfs;
    char rootUsed[32] = "0G", rootTotal[32] = "0G";
    int rootPct = 0;
    if (statvfs("/", &rfs) == 0 && rfs.f_blocks > 0) {
        double tot = static_cast<double>(rfs.f_blocks * rfs.f_frsize) / (1024.0 * 1024.0 * 1024.0);
        double avail = static_cast<double>(rfs.f_bavail * rfs.f_frsize) / (1024.0 * 1024.0 * 1024.0);
        double used = (tot > avail) ? (tot - avail) : 0.0;
        rootPct = static_cast<int>((used / tot) * 100.0);
        snprintf(rootUsed, sizeof(rootUsed), "%.0fG", used);
        snprintf(rootTotal, sizeof(rootTotal), "%.0fG", tot);
    }

    char homeUsed[32] = "0G", homeTotal[32] = "0G";
    int homePct = 0;
    const char* homePath = (statvfs("/home", &hfs) == 0 && hfs.f_blocks > 0) ? "/home" : "/";
    statvfs(homePath, &hfs);
    if (hfs.f_blocks > 0) {
        double tot = static_cast<double>(hfs.f_blocks * hfs.f_frsize) / (1024.0 * 1024.0 * 1024.0);
        double avail = static_cast<double>(hfs.f_bavail * hfs.f_frsize) / (1024.0 * 1024.0 * 1024.0);
        double used = (tot > avail) ? (tot - avail) : 0.0;
        homePct = static_cast<int>((used / tot) * 100.0);
        snprintf(homeUsed, sizeof(homeUsed), "%.0fG", used);
        snprintf(homeTotal, sizeof(homeTotal), "%.0fG", tot);
    }

    // 6. CPU Temperature
    int cpuTemp = 45;
    glob_t globBuf;
    if (glob("/sys/class/hwmon/hwmon*/temp*_input", 0, nullptr, &globBuf) == 0) {
        for (size_t i = 0; i < globBuf.gl_pathc; ++i) {
            std::string tStr = readFile(globBuf.gl_pathv[i]);
            if (!tStr.empty()) {
                int tVal = std::stoi(tStr);
                if (tVal > 10000 && tVal < 120000) {
                    cpuTemp = tVal / 1000;
                    break;
                }
            }
        }
        globfree(&globBuf);
    } else if (glob("/sys/class/thermal/thermal_zone*/temp", 0, nullptr, &globBuf) == 0) {
        for (size_t i = 0; i < globBuf.gl_pathc; ++i) {
            std::string tStr = readFile(globBuf.gl_pathv[i]);
            if (!tStr.empty()) {
                int tVal = std::stoi(tStr);
                if (tVal > 10000 && tVal < 120000) {
                    cpuTemp = tVal / 1000;
                    break;
                }
            }
        }
        globfree(&globBuf);
    }

    // 7. Battery Status, AC Online & Capacity
    int batteryCap = 100;
    std::string batteryStatus = "AC POWER";
    bool isAcOnline = false;
    int secondsRemaining = 0;

    glob_t acGlob;
    if (glob("/sys/class/power_supply/AC*/online", 0, nullptr, &acGlob) == 0) {
        for (size_t i = 0; i < acGlob.gl_pathc; ++i) {
            std::string onlineStr = readFile(acGlob.gl_pathv[i]);
            if (onlineStr == "1") {
                isAcOnline = true;
                break;
            }
        }
        globfree(&acGlob);
    }

    if (glob("/sys/class/power_supply/BAT*", 0, nullptr, &globBuf) == 0) {
        if (globBuf.gl_pathc > 0) {
            std::string batDir = std::string(globBuf.gl_pathv[0]);
            std::string capStr = readFile(batDir + "/capacity");
            std::string statStr = readFile(batDir + "/status");
            if (!capStr.empty()) batteryCap = std::stoi(capStr);
            if (!statStr.empty()) batteryStatus = statStr;

            std::string energyStr = readFile(batDir + "/energy_now");
            std::string powerStr = readFile(batDir + "/power_now");
            if (energyStr.empty()) energyStr = readFile(batDir + "/charge_now");
            if (powerStr.empty()) powerStr = readFile(batDir + "/current_now");

            if (!energyStr.empty() && !powerStr.empty()) {
                try {
                    long long e = std::stoll(energyStr);
                    long long p = std::stoll(powerStr);
                    if (p > 0) {
                        secondsRemaining = static_cast<int>((e * 3600ULL) / p);
                    }
                } catch (...) {}
            }
        }
        globfree(&globBuf);
    }

    // 8. CPU Total & Per-Core Loads (80ms delta)
    auto snap1 = readProcStat();
    usleep(80000); // 80ms
    auto snap2 = readProcStat();

    int cpuLoad = 0;
    std::vector<int> coreLoads;

    if (!snap1.empty() && snap1.size() == snap2.size()) {
        // Overall CPU
        unsigned long long dt = snap2[0].getTotal() - snap1[0].getTotal();
        unsigned long long did = snap2[0].getIdle() - snap1[0].getIdle();
        if (dt > 0 && dt >= did) {
            cpuLoad = static_cast<int>(((dt - did) * 100) / dt);
        }

        // Per-Core
        for (size_t i = 1; i < snap1.size(); ++i) {
            unsigned long long c_dt = snap2[i].getTotal() - snap1[i].getTotal();
            unsigned long long c_did = snap2[i].getIdle() - snap1[i].getIdle();
            int c_pct = 0;
            if (c_dt > 0 && c_dt >= c_did) {
                c_pct = static_cast<int>(((c_dt - c_did) * 100) / c_dt);
            }
            if (c_pct < 0) c_pct = 0;
            if (c_pct > 100) c_pct = 100;
            coreLoads.push_back(c_pct);
        }
    }

    // Format Core Loads JSON array
    std::stringstream coresJson;
    coresJson << "[";
    for (size_t i = 0; i < coreLoads.size(); ++i) {
        if (i > 0) coresJson << ",";
        coresJson << coreLoads[i];
    }
    coresJson << "]";

    // 9. GPU Telemetry (Intel & NVIDIA)
    std::string gpu1Name = "Intel Iris Xe Graphics (TigerLake GT2)";
    int gpu1Clock = 0;
    int gpu1MaxClock = 1300;
    std::string gpu1Driver = "i915";

    // Read Intel GPU Frequencies
    glob_t gpuGlob;
    if (glob("/sys/class/drm/card*/gt_act_freq_mhz", 0, nullptr, &gpuGlob) == 0 && gpuGlob.gl_pathc > 0) {
        std::string act = readFile(gpuGlob.gl_pathv[0]);
        if (!act.empty()) gpu1Clock = std::stoi(act);
        globfree(&gpuGlob);
    } else if (glob("/sys/devices/pci*/*/drm/card*/gt/gt0/rps_act_freq_mhz", 0, nullptr, &gpuGlob) == 0 && gpuGlob.gl_pathc > 0) {
        std::string act = readFile(gpuGlob.gl_pathv[0]);
        if (!act.empty()) gpu1Clock = std::stoi(act);
        globfree(&gpuGlob);
    }

    if (glob("/sys/class/drm/card*/gt_max_freq_mhz", 0, nullptr, &gpuGlob) == 0 && gpuGlob.gl_pathc > 0) {
        std::string maxF = readFile(gpuGlob.gl_pathv[0]);
        if (!maxF.empty()) gpu1MaxClock = std::stoi(maxF);
        globfree(&gpuGlob);
    }
    if (gpu1MaxClock <= 0) gpu1MaxClock = 1300;
    int gpu1Pct = static_cast<int>((gpu1Clock * 100.0) / gpu1MaxClock);
    if (gpu1Pct > 100) gpu1Pct = 100;

    std::string gpu2Name = "NVIDIA GeForce MX330 (GP108M)";
    std::string gpu2Status = "STANDBY";
    std::string gpu2Driver = "nouveau";
    if (glob("/sys/class/drm/card*/device/power/runtime_status", 0, nullptr, &gpuGlob) == 0 && gpuGlob.gl_pathc > 0) {
        for (size_t i = 0; i < gpuGlob.gl_pathc; ++i) {
            std::string p = gpuGlob.gl_pathv[i];
            if (p.find("0000:02:00.0") != std::string::npos || p.find("card1") != std::string::npos) {
                std::string st = readFile(p);
                if (!st.empty()) {
                    gpu2Status = st;
                    for (auto &c : gpu2Status) c = toupper(c);
                }
                break;
            }
        }
        globfree(&gpuGlob);
    }

    // 10. Output JSON
    char outBuffer[3072];
    snprintf(outBuffer, sizeof(outBuffer),
        "{\n"
        "  \"cpuModel\": \"%s\",\n"
        "  \"cpuLoad\": %d,\n"
        "  \"coreLoads\": %s,\n"
        "  \"cpuTemp\": %d,\n"
        "  \"hostName\": \"%s\",\n"
        "  \"kernelVer\": \"%s\",\n"
        "  \"boardName\": \"%s\",\n"
        "  \"batteryCap\": %d,\n"
        "  \"batteryStatus\": \"%s\",\n"
        "  \"isAcOnline\": %s,\n"
        "  \"secondsRemaining\": %d,\n"
        "  \"ramUsedGb\": \"%.1f\",\n"
        "  \"ramTotalGb\": \"%.1f\",\n"
        "  \"ramPct\": %d,\n"
        "  \"swapUsedGb\": \"%.1f\",\n"
        "  \"swapTotalGb\": \"%.1f\",\n"
        "  \"swapPct\": %d,\n"
        "  \"rootUsed\": \"%s\",\n"
        "  \"rootTotal\": \"%s\",\n"
        "  \"rootPct\": %d,\n"
        "  \"homeUsed\": \"%s\",\n"
        "  \"homeTotal\": \"%s\",\n"
        "  \"homePct\": %d,\n"
        "  \"gpu1Name\": \"%s\",\n"
        "  \"gpu1Clock\": %d,\n"
        "  \"gpu1MaxClock\": %d,\n"
        "  \"gpu1Pct\": %d,\n"
        "  \"gpu1Driver\": \"%s\",\n"
        "  \"gpu2Name\": \"%s\",\n"
        "  \"gpu2Status\": \"%s\",\n"
        "  \"gpu2Driver\": \"%s\"\n"
        "}\n",
        cpuModel.c_str(),
        cpuLoad,
        coresJson.str().c_str(),
        cpuTemp,
        hostName.c_str(),
        kernelVer.c_str(),
        boardName.c_str(),
        batteryCap,
        batteryStatus.c_str(),
        (isAcOnline ? "true" : "false"),
        secondsRemaining,
        ramUsedGb,
        ramTotalGb,
        ramPct,
        swapUsedGb,
        swapTotalGb,
        swapPct,
        rootUsed,
        rootTotal,
        rootPct,
        homeUsed,
        homeTotal,
        homePct,
        gpu1Name.c_str(),
        gpu1Clock,
        gpu1MaxClock,
        gpu1Pct,
        gpu1Driver.c_str(),
        gpu2Name.c_str(),
        gpu2Status.c_str(),
        gpu2Driver.c_str()
    );

    std::cout << outBuffer;
    return 0;
}
