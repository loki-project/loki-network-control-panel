#include "WindowsLokinetProcessManager.hpp"

#include <QProcess>
#include <QDebug>
#include <QStandardPaths>

#ifdef Q_OS_WIN

#include <cstdio>
#include <windows.h>
#include <tlhelp32.h>

// TODO: don't hard-code these paths
#define LOKINET_DIR "C:\\Program Files\\Loki Project\\loki-network"
#define LOKINET_PATH LOKINET_DIR "\\lokinet.exe"
#define LOKINET_EXE_STR "\"" LOKINET_PATH "\""

WindowsLokinetProcessManager::WindowsLokinetProcessManager()
{
    ::CreateMutexA(nullptr, FALSE, "lokinet_qt5_ui");
}

bool WindowsLokinetProcessManager::doStartLokinetProcess()
{
    // try searching one level up from CWD
    bool success = QProcess::startDetached(LOKINET_EXE_STR);
    if (! success)
    {
        // when upgraded from old installations (before 0.5.x), lokinet.exe would be one
        // directory higher
        success = QProcess::startDetached("..\\lokinet.exe");

        if (! success)
            qDebug("QProcess::startDetached() failed");
    }
    
    return success;
}

bool WindowsLokinetProcessManager::doForciblyStopLokinetProcess()
{
    int p;
    HANDLE lokinetProcess;
    
    if (doGetProcessPid(p))
        lokinetProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, (DWORD)p);
    else
        return false;
    
    if (TerminateProcess(lokinetProcess, 0))
        return true;
    else
        return false;

    return true;
}

bool WindowsLokinetProcessManager::doGetProcessPid(int& pid)
{

    PROCESSENTRY32 entry;
    entry.dwSize = sizeof(PROCESSENTRY32);

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    if (Process32First(snapshot, &entry) != TRUE)
    {
        CloseHandle(snapshot);
        qDebug() << "Process32First() returned false";
        return false;
    }
    else
    {
        while (Process32Next(snapshot, &entry) == TRUE)
        {
            if (wcscmp(entry.szExeFile, L"lokinet.exe") == 0)
            {  
                pid = entry.th32ProcessID;
                qDebug("lokinet pid: %d", pid);
                return true;
            }
        }
    }

    CloseHandle(snapshot);

    qDebug() << "No lokinet.exe found";

    return true;
}

QString WindowsLokinetProcessManager::getDefaultBootstrapFileLocation()
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + "\\AppData\\Roaming\\.lokinet\\bootstrap.signed";
}

#endif // Q_OS_WIN
