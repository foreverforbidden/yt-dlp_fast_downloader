#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>

using namespace std;

int main() {
    namespace fs = std::filesystem;

    fs::path optionsDir = "options";
    fs::path targetFile = optionsDir / "target.txt";

    if (!fs::exists(optionsDir)) {
        fs::create_directory(optionsDir);
    }

    if (!fs::exists(targetFile)) {
        ofstream out(targetFile);
        out << "powershell -noexit -File yt-dlp.ps1\n";
        out.close();
    }

    ifstream file(targetFile);
    if (!file) {
        cerr << "Failed to open " << targetFile << '\n';
        return 1;
    }

    string command;
    getline(file, command);

    if (command.empty()) {
        cerr << "Command file is empty\n";
        return 1;
    }

    system(command.c_str());
    return 0;
}
