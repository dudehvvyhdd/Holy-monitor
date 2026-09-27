#define MAX_HOLY 100
#define METER_WIDTH 32

I64 holy_score = 100;

U8 *unholy_apps[] = {
    "chrome",
    "chromium",
    "brave",
    "edge",
    "opera",
    "vivaldi",
    "discord",
    "slack",
    "teams",
    "element",
    "signal",
    "whatsapp",
    "telegram-desktop",
    "code",
    "postman",
    "insomnia",
    "gitkraken",
    "obsidian",
    "logseq",
    "spotify",
    "notion",
    "figma",
    "trello",
    "steam",
    NULL
};

I64 IsProcessRunning(U8 *proc_name) {
    U8 cmd[128];
    StrPrint(cmd, "pgrep -i %s > /dev/null 2>&1", proc_name);
    return System(cmd) == 0;
}

I64 CountUnholyApps() {
    I64 count = 0;
    I64 i = 0;
    while (unholy_apps[i] != NULL) {
        if (IsProcessRunning(unholy_apps[i])) {
            count++;
        }
        i++;
    }
    return count;
}

U0 PurgeAllUnholyApps() {
    I64 i = 0;
    U8 cmd[128];

    Print("\x1b[2J\x1b[H\x1b[31;1m");
    Print("===================================================\n");
    Print("   DIVINE JUDGMENT REACHED: PURGING ALL HERESY!    \n");
    Print("===================================================\n\n");

    while (unholy_apps[i] != NULL) {
        if (IsProcessRunning(unholy_apps[i])) {
            Print("[!] EXECUTING PURGE ON: %s\n", unholy_apps[i]);
            StrPrint(cmd, "pkill -9 -i %s > /dev/null 2>&1", unholy_apps[i]);
            System(cmd);
        }
        i++;
    }

    Print("\nAll unholy processes smitten. Sanctity restored!\n");
    Sleep(1500);

    holy_score = MAX_HOLY;
    Print("\x1b[2J");
}

U0 DrawWindow(I64 x, I64 y, I64 w, I64 h, U8 *title) {
    I64 i, j;
    
    Print("\x1b[%d;%dH\x1b[36;1m╔", y, x);
    for (i = 0; i < w - 2; i++) Print("═");
    Print("╗");

    if (title) Print("\x1b[%d;%dH\x1b[33;1m[ %s ]", y, x + 3, title);

    for (j = 1; j < h - 1; j++) {
        Print("\x1b[%d;%dH\x1b[36;1m║", y + j, x);
        Print("\x1b[%d;%dH\x1b[30;1m║", y + j, x + w - 1);
    }

    Print("\x1b[%d;%dH\x1b[30;1m╚", y + h - 1, x);
    for (i = 0; i < w - 2; i++) Print("═");
    Print("╝\x1b[0m");

    for (j = 1; j < h; j++) Print("\x1b[%d;%dH\x1b[30m░\x1b[0m", y + j, x + w);
    Print("\x1b[%d;%dH\x1b[30m", y + h, x + 1);
    for (i = 0; i < w; i++) Print("░");
    Print("\x1b[0m");
}

U0 DrawMeterAndStatus(I64 x, I64 y) {
    I64 filled = (holy_score * METER_WIDTH) / MAX_HOLY;
    I64 i;

    Print("\x1b[%d;%dH\x1b[36;1mSANCTITY: ", y, x);

    if (holy_score > 66)      Print("\x1b[32;1m");
    else if (holy_score > 33) Print("\x1b[33;1m");
    else                      Print("\x1b[31;1m");

    Print("[");
    for (i = 0; i < METER_WIDTH; i++) {
        if (i < filled) Print("█");
        else            Print("░");
    }
    Print("] %3d%%\x1b[0m", holy_score);

    Print("\x1b[%d;%dH\x1b[2K", y + 2, x);
    if (holy_score > 66) {
        Print("\x1b[%d;%dH\x1b[32;1mSTATUS: Pure Temple. God's lonely programmer smiles.\x1b[0m", y + 2, x);
    } else if (holy_score > 33) {
        Print("\x1b[%d;%dH\x1b[33;1mSTATUS: Terry Davis would not approve.\x1b[0m", y + 2, x);
    } else {
        Print("\x1b[%d;%dH\x1b[31;1mSTATUS: Await for your divine judgment!\x1b[0m", y + 2, x);
    }
}

U0 Main() {
    Print("\x1b[2J\x1b[?25l");

    while (TRUE) {
        DrawWindow(2, 2, 58, 12, "HOLY MONITOR (ETERNAL)");

        Print("\x1b[4;5H\x1b[36mTarget: \x1b[33mActive Process Guard\x1b[0m");

        I64 active_unholy = CountUnholyApps();

        if (active_unholy > 0) {
            Print("\x1b[6;5H\x1b[31;1m[!] WARNING: THEY ARE WATCHING! (%d UNHOLY APPS)\x1b[0m", active_unholy);
            holy_score -= (active_unholy * 10);
            if (holy_score < 0) holy_score = 0;
        } else {
            Print("\x1b[6;5H\x1b[2K");
            if (holy_score < MAX_HOLY) holy_score += 2;
        }

        DrawMeterAndStatus(5, 8);

        if (holy_score <= 0) {
            PurgeAllUnholyApps();
        }

        Sleep(300);
    }
}

Main;
