#ifndef HOLYC_NATIVE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <stdarg.h>

typedef int64_t I64;
typedef uint8_t U8;
typedef void    U0;

#define TRUE  1
#define FALSE 0

#define Print(...)       printf(__VA_ARGS__)
#define StrPrint(s, ...) sprintf((char *)(s), __VA_ARGS__)
#define System(cmd)      system((const char *)(cmd))
#define Sleep(ms)        usleep((ms) * 1000)
#endif

#define MAX_HOLY       100
#define METER_WIDTH    32
#define POLL_TIME      300

I64 holy_score = MAX_HOLY;

U8 *unholy_apps[] = {
    (U8 *)"chrome",
    (U8 *)"chromium",
    (U8 *)"brave",
    (U8 *)"edge",
    (U8 *)"opera",
    (U8 *)"vivaldi",
    (U8 *)"discord",
    (U8 *)"slack",
    (U8 *)"teams",
    (U8 *)"element",
    (U8 *)"signal",
    (U8 *)"whatsapp",
    (U8 *)"telegram-desktop",
    (U8 *)"code",
    (U8 *)"postman",
    (U8 *)"insomnia",
    (U8 *)"gitkraken",
    (U8 *)"obsidian",
    (U8 *)"logseq",
    (U8 *)"spotify",
    (U8 *)"notion",
    (U8 *)"figma",
    (U8 *)"trello",
    (U8 *)"steam",
    NULL
};

I64 IsProcessRunning(U8 *proc_name)
{
    U8 cmd[128];

    StrPrint(
        cmd,
        "pgrep -ix '%s' > /dev/null 2>&1",
        proc_name
    );

    return System(cmd) == 0;
}

I64 CountUnholyApps()
{
    I64 count = 0;
    I64 i = 0;

    while (unholy_apps[i] != NULL)
    {
        if (IsProcessRunning(unholy_apps[i]))
            count++;

        i++;
    }

    return count;
}

U0 ApplyUnholiness(I64 active_unholy)
{
    I64 punishment;

    if (active_unholy <= 0)
        return;

    punishment = 4 + ((active_unholy - 1) * 2);

    holy_score -= punishment;

    if (holy_score < 0)
        holy_score = 0;
}

U0 RestoreHoliness()
{
    if (holy_score < MAX_HOLY)
    {
        holy_score += 1;

        if (holy_score > MAX_HOLY)
            holy_score = MAX_HOLY;
    }
}

U0 PurgeAllUnholyApps()
{
    I64 i = 0;
    U8 cmd[128];

    Print("\x1b[2J\x1b[H\x1b[31;1m");
    Print("DIVINE JUDGMENT REACHED: PURGING ALL HERESY!\n\n");

    while (unholy_apps[i] != NULL)
    {
        if (IsProcessRunning(unholy_apps[i]))
        {
            Print(
                "[!] EXECUTING PURGE ON: %s\n",
                unholy_apps[i]
            );

            StrPrint(
                cmd,
                "pkill -9 -ix '%s' > /dev/null 2>&1",
                unholy_apps[i]
            );

            System(cmd);
        }

        i++;
    }

    Print("\nAll unholy processes smitten. Sanctity restored!\n");

    Sleep(1500);

    holy_score = MAX_HOLY;

    Print("\x1b[2J\x1b[H\x1b[0m");
}

U0 DrawWindow(
    I64 x,
    I64 y,
    I64 w,
    I64 h,
    U8 *title
)
{
    I64 i;
    I64 j;

    Print(
        "\x1b[%ld;%ldH\x1b[36;1m╔",
        (long)y,
        (long)x
    );

    for (i = 0; i < w - 2; i++)
        Print("═");

    Print("╗");

    if (title)
    {
        Print(
            "\x1b[%ld;%ldH\x1b[33;1m[ %s ]",
            (long)y,
            (long)x + 3,
            title
        );
    }

    for (j = 1; j < h - 1; j++)
    {
        Print(
            "\x1b[%ld;%ldH\x1b[36;1m║",
            (long)y + j,
            (long)x
        );

        Print(
            "\x1b[%ld;%ldH\x1b[36;1m║",
            (long)y + j,
            (long)x + w - 1
        );
    }

    Print(
        "\x1b[%ld;%ldH\x1b[36;1m╚",
        (long)y + h - 1,
        (long)x
    );

    for (i = 0; i < w - 2; i++)
        Print("═");

    Print("╝\x1b[0m");
}

U0 DrawMeterAndStatus(
    I64 x,
    I64 y,
    I64 active_unholy
)
{
    I64 filled;
    I64 i;

    filled = (holy_score * METER_WIDTH) / MAX_HOLY;

    Print(
        "\x1b[%ld;%ldH\x1b[36;1mSANCTITY: ",
        (long)y,
        (long)x
    );

    if (holy_score > 66)
        Print("\x1b[32;1m");
    else if (holy_score > 33)
        Print("\x1b[33;1m");
    else
        Print("\x1b[31;1m");

    Print("[");

    for (i = 0; i < METER_WIDTH; i++)
    {
        if (i < filled)
            Print("█");
        else
            Print("░");
    }

    Print(
        "] %3ld%%\x1b[0m",
        (long)holy_score
    );

    Print(
        "\x1b[%ld;%ldH\x1b[2K\x1b[36;1mACTIVE HERESY: \x1b[31;1m%ld\x1b[0m",
        (long)y + 1,
        (long)x,
        (long)active_unholy
    );

    Print(
        "\x1b[%ld;%ldH\x1b[2K",
        (long)y + 2,
        (long)x
    );

    if (holy_score > 66)
    {
        Print(
            "\x1b[%ld;%ldH\x1b[32;1mSTATUS: Pure Temple. God's lonely programmer smiles.\x1b[0m",
            (long)y + 2,
            (long)x
        );
    }
    else if (holy_score > 33)
    {
        Print(
            "\x1b[%ld;%ldH\x1b[33;1mSTATUS: Terry Davis would not approve.\x1b[0m",
            (long)y + 2,
            (long)x
        );
    }
    else
    {
        Print(
            "\x1b[%ld;%ldH\x1b[31;1mSTATUS: Await your divine judgment!\x1b[0m",
            (long)y + 2,
            (long)x
        );
    }
}

#ifndef HOLYC_NATIVE
void Cleanup(int sig)
{
    (void)sig;

    Print("\x1b[0m\x1b[2J\x1b[H");

    exit(0);
}
#endif

int main(void)
{
#ifndef HOLYC_NATIVE
    signal(SIGINT, Cleanup);
    signal(SIGTERM, Cleanup);
#endif

    Print("\x1b[2J\x1b[H\x1b[0m");

    while (TRUE)
    {
        I64 active_unholy;

        DrawWindow(
            2,
            2,
            58,
            13,
            (U8 *)"HOLY MONITOR (ETERNAL)"
        );

        Print(
            "\x1b[4;5H\x1b[36mTarget: \x1b[33mActive Process Guard\x1b[0m"
        );

        active_unholy = CountUnholyApps();

        if (active_unholy > 0)
        {
            Print(
                "\x1b[6;5H\x1b[31;1m[!] WARNING: THEY ARE WATCHING! (%ld UNHOLY APPS)\x1b[0m",
                (long)active_unholy
            );

            ApplyUnholiness(active_unholy);
        }
        else
        {
            Print("\x1b[6;5H\x1b[2K");

            RestoreHoliness();
        }

        DrawMeterAndStatus(
            5,
            8,
            active_unholy
        );

        if (holy_score <= 0)
        {
            PurgeAllUnholyApps();
        }

        Sleep(POLL_TIME);
    }

    return 0;
}
