@echo off
setlocal
set "PS_FILE=%TEMP%\GhostWorld_Checker_Runtime.ps1"
if exist "%PS_FILE%" del "%PS_FILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0'; $f=[IO.File]::ReadAllLines($p, [Text.Encoding]::UTF8); $i=-1; for($n=0;$n -lt $f.Length;$n++){if($f[$n] -match '^#PS_START'){$i=$n;break}}; if($i -ge 0){[IO.File]::WriteAllLines('%PS_FILE%',$f[$i..($f.Length-1)],(New-Object Text.UTF8Encoding $true))}"

if not exist "%PS_FILE%" (
    echo [ERROR] Extraction failed. Save as UTF-8.
    pause
    goto :eof
)

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS_FILE%"
set RC=%ERRORLEVEL%
if exist "%PS_FILE%" del "%PS_FILE%"

if not "%RC%"=="0" (
    echo.
    echo [ERROR] PowerShell returned %RC%
    pause
)

goto :eof
#PS_START
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Win32 API
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace GW {
    public class Native { [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey); }
    public class Injector {
        [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)] public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
        [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true)] public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto)] public static extern IntPtr GetModuleHandle(string lpModuleName);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr hObject);
        public static bool Inject(int pid, string dllPath) {
            IntPtr hProc = OpenProcess(0x1F0FFF, false, pid);
            if (hProc == IntPtr.Zero) return false;
            IntPtr loc = VirtualAllocEx(hProc, IntPtr.Zero, (uint)((dllPath.Length + 1) * 2), 0x1000, 0x40);
            if (loc == IntPtr.Zero) { CloseHandle(hProc); return false; }
            byte[] bytes = System.Text.Encoding.Unicode.GetBytes(dllPath + "\0");
            UIntPtr bytesWritten;
            WriteProcessMemory(hProc, loc, bytes, (uint)bytes.Length, out bytesWritten);
            IntPtr hKernel32 = GetModuleHandle("kernel32.dll");
            IntPtr loadLibraryAddr = GetProcAddress(hKernel32, "LoadLibraryW");
            IntPtr hThread = CreateRemoteThread(hProc, IntPtr.Zero, 0, loadLibraryAddr, loc, 0, IntPtr.Zero);
            CloseHandle(hProc);
            return hThread != IntPtr.Zero;
        }
    }
}
"@

$script:cfgPath = "$env:APPDATA\GhostWorld\settings.json"
$dir = Split-Path $script:cfgPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$script:cfg = @{ accent = "#00FFCC" }
if (Test-Path $script:cfgPath) { try { $script:cfg = Get-Content $script:cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }

# === ОКНО ВЫБОРА ЯЗЫКА (Увеличен размер и отступы) ===
$lx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Language" Height="550" Width="500" Background="Transparent" WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True" ResizeMode="NoResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.4"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Window.Resources>
    <Style TargetType="Button" x:Key="LangBtn">
        <Setter Property="Background" Value="#111111"/><Setter Property="Foreground" Value="$( $script:cfg.accent )"/>
        <Setter Property="FontSize" Value="16"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="0,0,0,12"/>
        <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="border" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="1" Padding="15"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="border" Property="BorderBrush" Value="$( $script:cfg.accent )"/><Setter TargetName="border" Property="Background" Value="#1A1A1A"/><Setter Property="Effect"><Setter.Value><DropShadowEffect Color="$( $script:cfg.accent )" BlurRadius="15" ShadowDepth="0" Opacity="0.5"/></Setter.Value></Setter></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
</Window.Resources>
<Border CornerRadius="15" BorderBrush="$( $script:cfg.accent )" BorderThickness="1" Background="#080808">
    <Grid>
        <Grid.RowDefinitions><RowDefinition Height="40"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Grid Grid.Row="0" Background="Transparent"><Button x:Name="btnLangClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Margin="0,5,5,0" Background="Transparent" Foreground="#888" FontSize="14" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
        <StackPanel Grid.Row="1" Margin="40,0,40,20" VerticalAlignment="Center">
            <TextBlock Text="GW CHECKER" Foreground="$( $script:cfg.accent )" FontSize="36" FontWeight="Bold" FontFamily="Segoe UI" HorizontalAlignment="Center"><TextBlock.Effect><DropShadowEffect Color="$( $script:cfg.accent )" BlurRadius="20" ShadowDepth="0" Opacity="0.8"/></TextBlock.Effect></TextBlock>
            <TextBlock Text="v38.0" Foreground="#666" FontSize="14" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,25"/>
            <TextBlock Text="Выбери язык / Обери мову / Select language" Foreground="#FFF" FontSize="14" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,25"/>
            <Button x:Name="btnRU" Content="Русский" Height="45" Style="{StaticResource LangBtn}"/>
            <Button x:Name="btnUA" Content="Українська" Height="45" Style="{StaticResource LangBtn}"/>
            <Button x:Name="btnEN" Content="English" Height="45" Style="{StaticResource LangBtn}"/>
        </StackPanel>
    </Grid>
</Border>
</Window>
"@
$lw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$lx)))
$lw.Add_MouseLeftButtonDown({ try{$lw.DragMove()}catch{} })
$script:lang = "RU"
$lw.FindName("btnRU").Add_Click({ $script:lang="RU"; $lw.Close() })
$lw.FindName("btnUA").Add_Click({ $script:lang="UA"; $lw.Close() })
$lw.FindName("btnEN").Add_Click({ $script:lang="EN"; $lw.Close() })
$lw.FindName("btnLangClose").Add_Click({ $lw.Close() })
$lw.ShowDialog() | Out-Null

$script:T = @{
  RU = @{
    title="GhostWorld - Проверка читов"; version="ПРОВЕРКА v38.0"
    nav_mc="🎮 MINECRAFT"; nav_sys="🛡️ СИСТЕМА"; nav_an="🔍 АНАЛИЗ"; nav_tools="🧠 УТИЛИТЫ"; nav_rules="📜 ПРАВИЛА"; nav_set="⚙️ НАСТРОЙКИ"
    btn_mods="Папки модов"; btn_logs="Логи игр"; btn_deep="Глубокая проверка"; btn_java="Java инжекторы"; btn_inject="Инжект в игру"
    btn_procs="Процессы (Cheat Engine)"; btn_reg="Реестр"; btn_sys="Службы и дампы"; btn_auto="Автозапуск"; btn_hosts="Открыть Hosts"
    btn_folder="Анализ папки"; btn_ai="AI Глубокий анализ"; btn_recent="Недавние файлы"; btn_installed="Установленные программы"
    btn_macro="Макросы и USB"; btn_task="Планировщик задач"; btn_sig="Цифровые подписи"; btn_every="Поиск Everything"; btn_remover="☢️ УДАЛЕНИЕ ЧИТОВ"; btn_clear="Очистить консоль"
    r_ready="Готово."; r_title="РЕЗУЛЬТАТЫ"; r_ok="ЧИСТО"; r_warn="ВНИМАНИЕ"; r_cheat="ЧИТ"; r_sum="Чисто: {0} | Внимание: {1} | Читы: {2}"; r_okbtn="ОК"; r_save="СОХРАНИТЬ"; r_copy="КОПИРОВАТЬ"; r_saved="Отчёт сохранён"; r_copied="Скопировано"
    rm_title="УДАЛЕНИЕ"; rm_sub="Удаляет читы в Корзину"; rm_scan="СКАНИРОВАТЬ"; rm_kill="УБИТЬ"; rm_sel="ВЫБРАТЬ ВСЁ"; rm_del="УДАЛИТЬ"; rm_ready="Нажмите СКАНИРОВАТЬ"; rm_scanning="Сканирую..."; rm_found="Найдено: {0}"; rm_none="Чисто."; rm_killing="Убиваю..."; rm_killed="Убито: {0}"; rm_conf_t="Вопрос"; rm_conf_m="Удалить {0}?"; rm_done_t="Готово"; rm_done_m="Удалено: {0}, Ошибок: {1}"; rm_col_found="НАЙДЕНО:"; rm_col_del="УДАЛЕНО:"
    folder_t="Анализ папки"; folder_pick="ВЫБРАТЬ"; folder_scan="АНАЛИЗ"; folder_none="Не выбрана"; folder_scanning="Сканирую..."; folder_done="Готово"; folder_noitems="Чисто"; folder_found="Найдено: {0}"; folder_browse="Папка"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR архив"; folder_scan_sub="Подпапки"
    set_acc="Цвет акцента (HEX):"; set_save="СОХРАНИТЬ"; set_warn="Перезапусти прогу для применения!"
    cat_mod="Чит-мод"; cat_lib="Библиотека"; cat_ver="Версия"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Ярлык"; cat_temp="Temp"; cat_dl="Загрузки"; cat_autorun="Автозапуск"; cat_folder="Папка"; cat_jar="JAR"; cat_ai="AI"
  }
  UA = @{
    title="GhostWorld - Перевірка читів"; version="ПЕРЕВІРКА v38.0"
    nav_mc="🎮 MINECRAFT"; nav_sys="🛡️ СИСТЕМА"; nav_an="🔍 АНАЛІЗ"; nav_tools="🧠 УТИЛІТИ"; nav_rules="📜 ПРАВИЛА"; nav_set="⚙️ НАЛАШТУВАННЯ"
    btn_mods="Папки модів"; btn_logs="Логи ігор"; btn_deep="Глибока перевірка"; btn_java="Java інжектори"; btn_inject="Інжект в гру"
    btn_procs="Процеси (Cheat Engine)"; btn_reg="Реєстр"; btn_sys="Служби та дампи"; btn_auto="Автозапуск"; btn_hosts="Відкрити Hosts"
    btn_folder="Аналіз папки"; btn_ai="AI Глибокий аналіз"; btn_recent="Недавні файли"; btn_installed="Встановлені програми"
    btn_macro="Макроси та USB"; btn_task="Планувальник"; btn_sig="Цифрові підписи"; btn_every="Пошук Everything"; btn_remover="☢️ ВИДАЛЕННЯ ЧИТІВ"; btn_clear="Очистити консоль"
    r_ready="Готово."; r_title="РЕЗУЛЬТАТИ"; r_ok="ЧИСТО"; r_warn="УВАГА"; r_cheat="ЧИТ"; r_sum="Чисто: {0} | Увага: {1} | Чити: {2}"; r_okbtn="ОК"; r_save="ЗБЕРЕГТИ"; r_copy="КОПІЮВАТИ"; r_saved="Збережено"; r_copied="Скопійовано"
    rm_title="ВИДАЛЕННЯ"; rm_sub="Видаляє в Кошик"; rm_scan="СКАНУВАТИ"; rm_kill="ВБИТИ"; rm_sel="ВСЕ"; rm_del="ВИДАЛИТИ"; rm_ready="Натисніть СКАНУВАТИ"; rm_scanning="Сканую..."; rm_found="Знайдено: {0}"; rm_none="Чисто."; rm_killing="Вбиваю..."; rm_killed="Вбито: {0}"; rm_conf_t="Питання"; rm_conf_m="Видалити {0}?"; rm_done_t="Готово"; rm_done_m="Видалено: {0}, Помилок: {1}"; rm_col_found="ЗНАЙДЕНО:"; rm_col_del="ВИДАЛЕНО:"
    folder_t="Аналіз папки"; folder_pick="ОБРАТИ"; folder_scan="АНАЛІЗ"; folder_none="Не обрана"; folder_scanning="Сканую..."; folder_done="Готово"; folder_noitems="Чисто"; folder_found="Знайдено: {0}"; folder_browse="Папка"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR"; folder_scan_sub="Підпапки"
    set_acc="Колір акценту (HEX):"; set_save="ЗБЕРЕГТИ"; set_warn="Перезапусти програму!"
    cat_mod="Чит-мод"; cat_lib="Бібліотека"; cat_ver="Версія"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Ярлик"; cat_temp="Temp"; cat_dl="Завантаження"; cat_autorun="Автозапуск"; cat_folder="Папка"; cat_jar="JAR"; cat_ai="AI"
  }
  EN = @{
    title="GhostWorld - Cheat Checker"; version="CHECKER v38.0"
    nav_mc="🎮 MINECRAFT"; nav_sys="🛡️ SYSTEM"; nav_an="🔍 ANALYSIS"; nav_tools="🧠 TOOLS"; nav_rules="📜 RULES"; nav_set="⚙️ SETTINGS"
    btn_mods="Mods Folders"; btn_logs="Game Logs"; btn_deep="Deep Scan"; btn_java="Java Injectors"; btn_inject="Inject into Game"
    btn_procs="Processes (Cheat Engine)"; btn_reg="Registry"; btn_sys="Services and Dumps"; btn_auto="Autostart"; btn_hosts="Open Hosts"
    btn_folder="Folder Analysis"; btn_ai="AI Deep Scan"; btn_recent="Recent Files"; btn_installed="Installed Programs"
    btn_macro="Macros and USB"; btn_task="Task Scheduler"; btn_sig="Signatures"; btn_every="Everything Search"; btn_remover="☢️ CHEAT REMOVER"; btn_clear="Clear Console"
    r_ready="Ready."; r_title="RESULTS"; r_ok="CLEAN"; r_warn="SUSPICIOUS"; r_cheat="CHEAT"; r_sum="Clean: {0} | Suspicious: {1} | Cheats: {2}"; r_okbtn="OK"; r_save="SAVE"; r_copy="COPY"; r_saved="Saved"; r_copied="Copied"
    rm_title="REMOVER"; rm_sub="Deletes cheats to Recycle Bin"; rm_scan="SCAN"; rm_kill="KILL"; rm_sel="SELECT ALL"; rm_del="DELETE"; rm_ready="Click SCAN"; rm_scanning="Scanning..."; rm_found="Found: {0}"; rm_none="Clean."; rm_killing="Killing..."; rm_killed="Killed: {0}"; rm_conf_t="Confirm"; rm_conf_m="Delete {0}?"; rm_done_t="Done"; rm_done_m="Deleted: {0}, Failed: {1}"; rm_col_found="FOUND:"; rm_col_del="DELETED:"
    folder_t="Folder Analysis"; folder_pick="PICK"; folder_scan="ANALYZE"; folder_none="Not selected"; folder_scanning="Scanning..."; folder_done="Done"; folder_noitems="Clean"; folder_found="Found: {0}"; folder_browse="Folder"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR content"; folder_scan_sub="Subfolders"
    set_acc="Accent Color (HEX):"; set_save="SAVE"; set_warn="Restart app to apply fully!"
    cat_mod="Cheat Mod"; cat_lib="Library"; cat_ver="Version"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Shortcut"; cat_temp="Temp"; cat_dl="Downloads"; cat_autorun="Autostart"; cat_folder="Folder"; cat_jar="JAR"; cat_ai="AI"
  }
}
function L([string]$k) { try { $v=$script:T[$script:lang][$k]; if($null -eq $v){return $k}; return [string]$v } catch { return $k } }

$cheats = "impact|wurst|aristois|baritone|liquidbounce|rusherhack|future|konas|salhack|kamiblue|sigma|vape|novoline|tenacity|rise|astolfo|krypton|moonproject|akrien|celestial|forgehax|inertia|wexside|wolfram|bleach|pyro|jigsaw|candycrack|flux|nurik|minced|nightmare|augustus|thunderhack|fatal|resolute|centric|delta|catlavan|quick|dimasik|skycor|energy|norules|matix|deadcode|eternity|rich|editme|mc100|r3d|wild|boberware|cortex|wex|hitbox|fluger|jessica|freecam|inventorytotem|chestlocator|valex|fabaritone|crack|celka|keazclient|tofficlient|darkness|archware|intave|nova|haramdev|shitclient|ponosclient|vegaline|newlight|exclusive|tenseclient|moonhack|deltaclient|hachclient|fullmyst|gothaj|sirius|wave|veristclient|avalon|wissendfree|resolutefree|kwishfree|centricfree|tutotialclient|fecuritysq|noclips|koshkadlc|flauncher|atmosphere|hider|huzuni|neverhook|exloader|calestial|clowdyclient|vert|vapeclient|clownclient|norender|extremehack|asteria|aimmbot|elytra_swap|smart_moving|chest_stealer|topkaautobuy|doomsday|viaversion|viamcp|spambot|xray|x-ray|killaura|wallhack|aimbot|newlauncher|new_launcher|new-launcher|exclusion|exclusionlauncher|exclusion_launcher|exclusion-launcher"
$badProcs = "cheatengine|processhacker|x64dbg|ollydbg|ida64|wireshark|fiddler|dnspy|extremeinjector|xenos|scylla|artmoney|hxd"
$badApps = "Cheat Engine|Process Hacker|HxD|DB Browser|Wireshark|x64dbg|OllyDbg|IDA Pro|Scylla|Extreme Injector|Fiddler|Charles|ArtMoney|SAO Utils"

function Get-LauncherFolders {
    @("$env:APPDATA\.minecraft","$env:APPDATA\.tlauncher","$env:APPDATA\TLauncher","$env:APPDATA\MultiMC","$env:APPDATA\PrismLauncher","$env:APPDATA\.lunarclient","$env:APPDATA\.badlion","$env:APPDATA\.feather","$env:APPDATA\.salwyrr","$env:APPDATA\.newlauncher","$env:APPDATA\NewLauncher","$env:LOCALAPPDATA\NewLauncher","$env:LOCALAPPDATA\.newlauncher","$env:APPDATA\.exclusion","$env:APPDATA\Exclusion","$env:LOCALAPPDATA\Exclusion","$env:USERPROFILE\.minecraft") | Where-Object { Test-Path $_ } | Select-Object -Unique
}

$histDir = "$env:APPDATA\GhostWorld"; if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Path $histDir -Force | Out-Null }
$histFile = Join-Path $histDir "history.json"
function Save-History($scanType) { try { $entry = [PSCustomObject]@{ time = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); type = $scanType; ok = @($script:Results | Where-Object { $_.Sev -eq 0 }).Count; warn = @($script:Results | Where-Object { $_.Sev -eq 1 }).Count; cheat = @($script:Results | Where-Object { $_.Sev -eq 2 }).Count; items = @($script:Results | Select-Object Cat, Text, Sev) }; $all = @(); if (Test-Path $histFile) { try { $all = @(Get-Content $histFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $all = @() } }; $all = @($entry) + $all; if ($all.Count -gt 100) { $all = $all[0..99] }; $all | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8 } catch {} }

# === ОСНОВНОЕ ОКНО ===
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'title')" Height="800" Width="1050" MinHeight="600" MinWidth="850" Background="Transparent" WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Window.Resources>
    <Style TargetType="{x:Type ScrollBar}"><Setter Property="Width" Value="8"/><Setter Property="Background" Value="Transparent"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="{x:Type ScrollBar}"><Grid Background="{TemplateBinding Background}" Margin="2,0"><Track x:Name="PART_Track" IsDirectionReversed="True"><Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton><Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="{x:Type Thumb}"><Border x:Name="thumbBorder" Background="#333" CornerRadius="4" Opacity="0.8"/><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="thumbBorder" Property="Background" Value="$( $script:cfg.accent )"/><Setter TargetName="thumbBorder" Property="Opacity" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Thumb.Template></Thumb></Track.Thumb><Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton></Track></Grid></ControlTemplate></Setter.Value></Setter></Style>
    <Style TargetType="Button" x:Key="MenuBtn"><Setter Property="Background" Value="#151515"/><Setter Property="Foreground" Value="$( $script:cfg.accent )"/><Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Margin" Value="0,0,0,5"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="1" Padding="12,10"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A2A2A"/><Setter TargetName="b" Property="BorderBrush" Value="$( $script:cfg.accent )"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
    <Style TargetType="Button" x:Key="CloseBtn"><Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="#888"/><Setter Property="FontSize" Value="16"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="10" Background="{TemplateBinding Background}" Width="30" Height="30"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FF3333"/><Setter Property="Foreground" Value="#FFF"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
    <Style TargetType="Button" x:Key="ActionBtn"><Setter Property="Background" Value="#151515"/><Setter Property="Foreground" Value="$( $script:cfg.accent )"/><Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="14"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Margin" Value="0,0,15,15"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Width" Value="200"/><Setter Property="Height" Value="45"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="1"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A2A2A"/><Setter TargetName="b" Property="BorderBrush" Value="$( $script:cfg.accent )"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
</Window.Resources>

<Border x:Name="mainBorder" CornerRadius="15" BorderBrush="#222" BorderThickness="1" Background="#0A0A0A">
<Grid>
<Grid.RowDefinitions><RowDefinition Height="45"/><RowDefinition Height="*"/></Grid.RowDefinitions>

<Grid x:Name="TitleBar" Grid.Row="0" Background="Transparent">
<TextBlock Text="GHOSTWORLD CHECKER" Foreground="$( $script:cfg.accent )" FontSize="16" FontWeight="Bold" FontFamily="Segoe UI" Margin="20,0,0,0" VerticalAlignment="Center"><TextBlock.Effect><DropShadowEffect x:Name="logoGlow" Color="$( $script:cfg.accent )" BlurRadius="10" ShadowDepth="0" Opacity="0.6"/></TextBlock.Effect></TextBlock>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,10,0"><Button x:Name="btnMin" Content="—" Style="{StaticResource CloseBtn}"/><Button x:Name="btnMax" Content="□" Style="{StaticResource CloseBtn}"/><Button x:Name="btnClose" Content="X" Style="{StaticResource CloseBtn}"/></StackPanel>
</Grid>

<Grid Grid.Row="1">
<Grid.ColumnDefinitions><ColumnDefinition Width="250"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

<Border Grid.Column="0" Background="#101010" CornerRadius="0,0,0,15" BorderBrush="#222" BorderThickness="0,1,1,0">
<StackPanel Margin="15,20,15,20">
<TextBlock Text="$(L 'version')" Foreground="#666" FontSize="12" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,20"/>
<Button x:Name="btnNavMc" Content="$(L 'nav_mc')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnNavSys" Content="$(L 'nav_sys')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnNavAn" Content="$(L 'nav_an')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnNavTools" Content="$(L 'nav_tools')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnNavRules" Content="$(L 'nav_rules')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnNavSet" Content="$(L 'nav_set')" Style="{StaticResource MenuBtn}"/>
</StackPanel>
</Border>

<Grid Grid.Column="1" Margin="20">
    <Grid x:Name="panelMc" Visibility="Visible">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="30"/></Grid.RowDefinitions>
        <TextBlock Text="🎮 MINECRAFT" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,20"/>
        <WrapPanel Grid.Row="1">
            <Button x:Name="btnScanMods" Content="$(L 'btn_mods')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnScanLogs" Content="$(L 'btn_logs')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnDeepScan" Content="$(L 'btn_deep')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnScanJava" Content="$(L 'btn_java')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnInject" Content="$(L 'btn_inject')" Style="{StaticResource ActionBtn}" Foreground="#FF4444"/>
        </WrapPanel>
        <TextBox x:Name="txtConMc" Grid.Row="2" Background="#050505" Foreground="#00FF00" FontFamily="Consolas" FontSize="12" IsReadOnly="True" Margin="0,10,0,0" BorderThickness="0" VerticalScrollBarVisibility="Auto"/>
        <Button Grid.Row="3" Content="$(L 'btn_clear')" Width="150" Height="25" HorizontalAlignment="Right" Background="#333" Foreground="#FFF" BorderThickness="0" Cursor="Hand" Margin="0,5,0,0" />
    </Grid>

    <Grid x:Name="panelSys" Visibility="Collapsed">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="30"/></Grid.RowDefinitions>
        <TextBlock Text="🛡️ СИСТЕМА" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,20"/>
        <WrapPanel Grid.Row="1">
            <Button x:Name="btnProcs" Content="$(L 'btn_procs')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnScanReg" Content="$(L 'btn_reg')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnScanSys" Content="$(L 'btn_sys')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnAutoRun" Content="$(L 'btn_auto')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnScanNet" Content="$(L 'btn_hosts')" Style="{StaticResource ActionBtn}"/>
        </WrapPanel>
        <TextBox x:Name="txtConSys" Grid.Row="2" Background="#050505" Foreground="#00FF00" FontFamily="Consolas" FontSize="12" IsReadOnly="True" Margin="0,10,0,0" BorderThickness="0" VerticalScrollBarVisibility="Auto"/>
        <Button Grid.Row="3" Content="$(L 'btn_clear')" Width="150" Height="25" HorizontalAlignment="Right" Background="#333" Foreground="#FFF" BorderThickness="0" Cursor="Hand" Margin="0,5,0,0" />
    </Grid>

    <Grid x:Name="panelAn" Visibility="Collapsed">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="30"/></Grid.RowDefinitions>
        <TextBlock Text="🔍 АНАЛИЗ" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,20"/>
        <WrapPanel Grid.Row="1">
            <Button x:Name="btnFolder" Content="$(L 'btn_folder')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnAiDeep" Content="$(L 'btn_ai')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnRecent" Content="$(L 'btn_recent')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnInstalled" Content="$(L 'btn_installed')" Style="{StaticResource ActionBtn}"/>
        </WrapPanel>
        <TextBox x:Name="txtConAn" Grid.Row="2" Background="#050505" Foreground="#00FF00" FontFamily="Consolas" FontSize="12" IsReadOnly="True" Margin="0,10,0,0" BorderThickness="0" VerticalScrollBarVisibility="Auto"/>
        <Button Grid.Row="3" Content="$(L 'btn_clear')" Width="150" Height="25" HorizontalAlignment="Right" Background="#333" Foreground="#FFF" BorderThickness="0" Cursor="Hand" Margin="0,5,0,0" />
    </Grid>

    <Grid x:Name="panelTools" Visibility="Collapsed">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="30"/></Grid.RowDefinitions>
        <TextBlock Text="🧠 УТИЛИТЫ" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,20"/>
        <WrapPanel Grid.Row="1">
            <Button x:Name="btnMacroScan" Content="$(L 'btn_macro')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnTaskSched" Content="$(L 'btn_task')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnSigCheck" Content="$(L 'btn_sig')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnEverything" Content="$(L 'btn_every')" Style="{StaticResource ActionBtn}"/>
            <Button x:Name="btnRemover" Content="$(L 'btn_remover')" Style="{StaticResource ActionBtn}" Foreground="#FF4444" Width="250"/>
        </WrapPanel>
        <TextBox x:Name="txtConTools" Grid.Row="2" Background="#050505" Foreground="#00FF00" FontFamily="Consolas" FontSize="12" IsReadOnly="True" Margin="0,10,0,0" BorderThickness="0" VerticalScrollBarVisibility="Auto"/>
        <Button Grid.Row="3" Content="$(L 'btn_clear')" Width="150" Height="25" HorizontalAlignment="Right" Background="#333" Foreground="#FFF" BorderThickness="0" Cursor="Hand" Margin="0,5,0,0" />
    </Grid>

    <Grid x:Name="panelRules" Visibility="Collapsed">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <TextBlock Text="$(L 'nav_rules')" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,15"/>
        <Border Grid.Row="1" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" CornerRadius="10" Padding="20">
            <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="rulesPanel"/></ScrollViewer>
        </Border>
    </Grid>

    <Grid x:Name="panelSet" Visibility="Collapsed">
        <StackPanel>
            <TextBlock Text="$(L 'nav_set')" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" Margin="0,0,0,20"/>
            <TextBlock Text="$(L 'set_acc')" Foreground="#CCC" FontSize="12" Margin="0,0,0,5"/>
            <TextBox x:Name="txtSetAccent" Text="$( $script:cfg.accent )" Background="#151515" Foreground="#FFF" FontSize="14" Padding="8" Margin="0,0,0,15" Width="200" HorizontalAlignment="Left" BorderThickness="1" BorderBrush="#333"/>
            <TextBlock Text="$(L 'set_warn')" Foreground="#FF5555" FontSize="11" Margin="0,0,0,20"/>
            <Button x:Name="btnSetSave" Content="$(L 'set_save')" Width="150" Height="40" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" BorderThickness="0" Cursor="Hand" HorizontalAlignment="Left"/>
        </StackPanel>
    </Grid>
</Grid>
<Thumb x:Name="rszMain" Width="15" Height="15" HorizontalAlignment="Right" VerticalAlignment="Bottom" Cursor="SizeNWSE" Panel.ZIndex="1000"/>
</Grid>
</Grid></Border></Window>
"@

$w = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$xaml)))
$w.Add_MouseLeftButtonDown({ param($sender, $e) if ($e.ClickCount -eq 2) { if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $w.WindowState = [Windows.WindowState]::Normal } else { $w.WindowState = [Windows.WindowState]::Maximized } } else { try { $w.DragMove() } catch {} } })
$mainBorder = $w.FindName("mainBorder")
$w.Add_StateChanged({ if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $mainBorder.CornerRadius = "0" } else { $mainBorder.CornerRadius = "15" } })
$w.FindName("btnClose").Add_Click({ $w.Close() }); $w.FindName("btnMin").Add_Click({ $w.WindowState = [Windows.WindowState]::Minimized }); $w.FindName("btnMax").Add_Click({ if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $w.WindowState = [Windows.WindowState]::Normal } else { $w.WindowState = [Windows.WindowState]::Maximized } })
$w.FindName("rszMain").Add_DragDelta({ $nw = $w.Width + $_.HorizontalChange; $nh = $w.Height + $_.VerticalChange; if ($nw -ge $w.MinWidth) { $w.Width = $nw }; if ($nh -ge $w.MinHeight) { $w.Height = $nh } })
$logoGlow = $w.FindName("logoGlow"); $logoAnim = New-Object Windows.Media.Animation.DoubleAnimation; $logoAnim.From = 0.6; $logoAnim.To = 1.0; $logoAnim.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds(1.5)); $logoAnim.AutoReverse = $true; $logoAnim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever; $logoGlow.BeginAnimation([Windows.Media.Effects.DropShadowEffect]::OpacityProperty, $logoAnim)

# Навигация
$panels = @{ mc=$w.FindName("panelMc"); sys=$w.FindName("panelSys"); an=$w.FindName("panelAn"); tools=$w.FindName("panelTools"); rules=$w.FindName("panelRules"); set=$w.FindName("panelSet") }
function Show-Panel($name) { foreach ($k in $panels.Keys) { $panels[$k].Visibility = "Collapsed" }; $panels[$name].Visibility = "Visible" }
$w.FindName("btnNavMc").Add_Click({ Show-Panel "mc" }); $w.FindName("btnNavSys").Add_Click({ Show-Panel "sys" }); $w.FindName("btnNavAn").Add_Click({ Show-Panel "an" }); $w.FindName("btnNavTools").Add_Click({ Show-Panel "tools" }); $w.FindName("btnNavRules").Add_Click({ Show-Panel "rules" }); $w.FindName("btnNavSet").Add_Click({ Show-Panel "set" })

function Log($m) { $cur = $panels.GetEnumerator() | Where-Object { $_.Value.Visibility -eq "Visible" } | Select-Object -First 1; $box = $w.FindName("txtCon" + $cur.Key.Replace("mc","Mc").Replace("sys","Sys").Replace("an","An").Replace("tools","Tools")); if ($box) { $box.AppendText("$m`r`n"); $box.ScrollToEnd() } }

$script:Results = New-Object System.Collections.ArrayList
function Add-Result($cat, $txt, $sev) { [void]$script:Results.Add([PSCustomObject]@{Cat=$cat;Text=$txt;Sev=$sev}) }

function Show-Results($scanType) {
    $rx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'r_title')" Height="720" Width="1050" MinHeight="400" MinWidth="650" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.35"/><DoubleAnimation Storyboard.TargetName="resBorder" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" From="40" To="0" Duration="0:0:0.4"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border x:Name="resBorder" CornerRadius="15" Background="#0A0A0A" BorderBrush="#333" BorderThickness="1"><Border.RenderTransform><TranslateTransform Y="40"/></Border.RenderTransform>
<Grid Margin="20"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,10"><TextBlock Text="$(L 'r_title')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold" FontFamily="Segoe UI"/><Button x:Name="btnResClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,15"><Border Background="#003300" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_ok')" Foreground="#00FF88" FontWeight="Bold"/></Border><Border Background="#332200" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_warn')" Foreground="#FFCC00" FontWeight="Bold"/></Border><Border Background="#330000" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_cheat')" Foreground="#FF4444" FontWeight="Bold"/></Border></StackPanel>
<Border Grid.Row="2" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="0"><DataGrid x:Name="dgResults" AutoGenerateColumns="False" Background="Transparent" RowBackground="Transparent" AlternatingRowBackground="#151515" Foreground="$( $script:cfg.accent )" BorderThickness="0" HeadersVisibility="Column" CanUserAddRows="False" IsReadOnly="True" GridLinesVisibility="None" RowHeight="25"><DataGrid.Columns><DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="140"/><DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="180"/><DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/></DataGrid.Columns></DataGrid></Border>
<Grid Grid.Row="3" Margin="0,15,0,0"><TextBlock x:Name="resSum" Foreground="#888" FontSize="12" VerticalAlignment="Center" FontFamily="Segoe UI"/><StackPanel Orientation="Horizontal" HorizontalAlignment="Right"><Button x:Name="btnCopy" Content="$(L 'r_copy')" Width="120" Height="35" Background="#333" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/><Button x:Name="btnSave" Content="$(L 'r_save')" Width="160" Height="35" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/><Button x:Name="btnOk" Content="$(L 'r_okbtn')" Width="90" Height="35" Background="#0055AA" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></StackPanel></Grid></Grid></Border></Window>
"@
    $rw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$rx)))
    $rw.Owner = $w; $rw.Add_MouseLeftButtonDown({ try { $rw.DragMove() } catch {} }); $rw.FindName("btnResClose").Add_Click({ $rw.Close() }); $rw.FindName("btnOk").Add_Click({ $rw.Close() })
    $ok=0; $wr=0; $ch=0; $viewData = @(); $report = New-Object System.Text.StringBuilder
    foreach ($r in $script:Results) {
        $statusText = "🟢 ЧИСТО"; if ($r.Sev -eq 1) { $statusText = "🟡 ВНИМАНИЕ"; $wr++ } elseif ($r.Sev -eq 2) { $statusText = "🔴 НАЙДЕНО"; $ch++ }
        else { $ok++ }
        $viewData += [PSCustomObject]@{ Status = $statusText; Category = $r.Cat; Path = $r.Text }
        [void]$report.AppendLine("[$($r.Sev)] [$($r.Cat)] $($r.Text)")
    }
    $rw.FindName("dgResults").ItemsSource = $viewData
    $rw.FindName("resSum").Text = (L 'r_sum') -f $ok, $wr, $ch
    if ($scanType) { Save-History $scanType }
    $rw.FindName("btnSave").Add_Click({ $path = "$env:USERPROFILE\Desktop\Report_$(Get-Date -Format 'HHmmss').txt"; [IO.File]::WriteAllText($path, $report.ToString(), (New-Object Text.UTF8Encoding $false)); [Windows.MessageBox]::Show("Сохранено: $path") })
    $rw.ShowDialog() | Out-Null
}

# Сканеры
function Do-ScanMods { Log "`r`n[>] Моды..."; $found=$false; foreach($mc in (Get-LauncherFolders)){ $md="$mc\mods"; if(Test-Path $md){ Get-ChildItem $md -Filter *.jar -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Чит-мод" $_.Name 2; $found=$true } } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Minecraft" "Чисто" 0 } }
function Do-ScanLogs { Log "`r`n[>] Логи..."; $found=$false; foreach($mc in (Get-LauncherFolders)){ $lf=Join-Path $mc "logs\latest.log"; if(Test-Path $lf){ Select-String -Path $lf -Pattern $cheats -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object { Log "[!] $($_.Line.Trim())"; Add-Result "Log" $_.Line.Trim() 2; $found=$true } } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Logs" "Чисто" 0 } }
function Do-ScanDeep { Log "`r`n[>] Глубокая..."; $found=$false; $pf="$env:SystemRoot\Prefetch"; if(Test-Path $pf){ Get-ChildItem $pf -Filter *.pf -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Prefetch" $_.Name 2; $found=$true } }; foreach($d in @("$env:APPDATA","$env:LOCALAPPDATA")){ Get-ChildItem $d -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "exclusion" } | ForEach-Object { Log "[!] $($_.FullName)"; Add-Result "AppData" $_.Name 2; $found=$true } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Deep" "Чисто" 0 } }
function Do-ScanJava { Log "`r`n[>] Java..."; $found=$false; Get-CimInstance Win32_Process -Filter "name='javaw.exe' or name='java.exe'" -ErrorAction SilentlyContinue | ForEach-Object { if ($_.CommandLine -match "agent|bootclasspath") { Log "[!] $($_.CommandLine)"; Add-Result "Java" $_.CommandLine 2; $found=$true } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Java" "Чисто" 0 } }
function Do-ScanReg { Log "`r`n[>] Реестр..."; $found=$false; $p="HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"; if(Test-Path $p){ (Get-ItemProperty -Path $p).PSObject.Properties | Where-Object { $_.Value -match $cheats } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Registry" $_.Name 2; $found=$true } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Registry" "Чисто" 0 } }
function Do-ScanSys { Log "`r`n[>] Службы..."; foreach($s in @("dps","sysmain","pcasvc","bam","appinfo")){ $svc=Get-Service -Name $s -ErrorAction SilentlyContinue; if($svc){ Log "$s : $($svc.Status)" } else { Log "$s : NO"; Add-Result "Service" "$s missing" 1 } }; if($script:Results.Count -eq 0){ Add-Result "System" "OK" 0 } }
function Do-ScanAutoRun { Log "`r`n[>] Автозапуск..."; $found=$false; foreach($k in @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")){ if(Test-Path $k){ (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" -and ($_.Value -match $cheats -or $_.Name -match $cheats) } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Автозапуск" $_.Name 2; $found=$true } } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Автозапуск" "Чисто" 0 } }
function Do-ScanMacro { Log "`r`n[>] Макросы..."; $mp=@("Razer","Logitech","Corsair","ROCCAT","Bloody","SteelSeries","AutoKey"); $r=Get-Process -ErrorAction SilentlyContinue | Where-Object { $n=$_.Name; $mp | Where-Object { $n -match $_ } }; if($r){ $r | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Macro" $_.Name 1 } } else { Add-Result "Macro" "Чисто" 0 } }
function Do-ScanTask { Log "`r`n[>] Таски..."; $found=$false; Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notmatch "\\Microsoft\\" } | ForEach-Object { $t=$_; foreach($a in $t.Actions){ if($a.Execute -match $cheats){ Log "[!] $($t.TaskName)"; Add-Result "Task" $t.TaskName 2; $found=$true } } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Tasks" "Чисто" 0 } }
function Do-ScanSig { Log "`r`n[>] Подписи..."; $found=$false; Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -ExpandProperty Path -Unique | ForEach-Object { $p=$_; if($p -match $env:SystemRoot -or $p -match "Program Files"){return}; try{ if((Get-AuthenticodeSignature -FilePath $p).Status -ne 'Valid'){ Log "[!] $p"; Add-Result "Unsigned" $p 1; $found=$true } }catch{} }; if(-not $found){ Log "[OK] OK."; Add-Result "Sig" "OK" 0 } }
function Do-ScanProcs { Log "`r`n[>] Процессы..."; $found=$false; Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $badProcs } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Process" $_.Name 1; $found=$true }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Process" "Чисто" 0 } }
function Do-ScanRecent { Log "`r`n[>] Недавние..."; $found=$false; $recent="$env:APPDATA\Microsoft\Windows\Recent"; if(Test-Path $recent){ Get-ChildItem $recent -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Recent" $_.Name 2; $found=$true } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Recent" "Чисто" 0 } }
function Do-ScanInstalled { Log "`r`n[>] Программы..."; $found=$false; $paths=@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"); foreach($p in $paths){ Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $badApps } | ForEach-Object { Log "[!] $($_.DisplayName)"; Add-Result "Installed" $_.DisplayName 1; $found=$true } }; if(-not $found){ Log "[OK] Чисто."; Add-Result "Installed" "Чисто" 0 } }

# Привязки кнопок
$w.FindName("btnScanMods").Add_Click({ $script:Results.Clear(); Do-ScanMods; Show-Results "Моды" })
$w.FindName("btnScanLogs").Add_Click({ $script:Results.Clear(); Do-ScanLogs; Show-Results "Логи" })
$w.FindName("btnDeepScan").Add_Click({ $script:Results.Clear(); Do-ScanDeep; Show-Results "Глубокая" })
$w.FindName("btnScanJava").Add_Click({ $script:Results.Clear(); Do-ScanJava; Show-Results "Java" })
$w.FindName("btnScanReg").Add_Click({ $script:Results.Clear(); Do-ScanReg; Show-Results "Реестр" })
$w.FindName("btnScanSys").Add_Click({ $script:Results.Clear(); Do-ScanSys; Show-Results "Система" })
$w.FindName("btnAutoRun").Add_Click({ $script:Results.Clear(); Do-ScanAutoRun; Show-Results "Автозапуск" })
$w.FindName("btnMacroScan").Add_Click({ $script:Results.Clear(); Do-ScanMacro; Show-Results "Макросы" })
$w.FindName("btnTaskSched").Add_Click({ $script:Results.Clear(); Do-ScanTask; Show-Results "Таски" })
$w.FindName("btnSigCheck").Add_Click({ $script:Results.Clear(); Do-ScanSig; Show-Results "Подписи" })
$w.FindName("btnProcs").Add_Click({ $script:Results.Clear(); Do-ScanProcs; Show-Results "Процессы" })
$w.FindName("btnRecent").Add_Click({ $script:Results.Clear(); Do-ScanRecent; Show-Results "Недавние" })
$w.FindName("btnInstalled").Add_Click({ $script:Results.Clear(); Do-ScanInstalled; Show-Results "Программы" })

$w.FindName("btnInject").Add_Click({
    $java = Get-Process -Name "javaw", "java" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $java) { [Windows.MessageBox]::Show("Minecraft не запущен!"); return }
    $dllPath = Join-Path $env:TEMP "gw_$(Get-Random).dll"
    try { Add-Type -TypeDefinition 'using System; using System.IO; public class GW { public static void Init() { File.WriteAllText(Environment.GetFolderPath(Environment.SpecialFolder.Desktop) + "\\Injected.txt", "OK"); } }' -OutputType Library -OutputAssembly $dllPath -ErrorAction Stop; [GW.Injector]::Inject($java.Id, $dllPath); [Windows.MessageBox]::Show("Инжект успешен!") } catch { [Windows.MessageBox]::Show("Ошибка инжекта.") }
})

$w.FindName("btnScanNet").Add_Click({ Start-Process notepad.exe "C:\Windows\System32\drivers\etc\hosts" })
$w.FindName("btnEverything").Add_Click({ $ev="$env:ProgramFiles\Everything\Everything.exe"; if(-not(Test-Path $ev)){$ev="${env:ProgramFiles(x86)}\Everything\Everything.exe"}; if(Test-Path $ev){ Start-Process $ev "-search `"ext:jar`"" } else { [Windows.MessageBox]::Show("Everything не установлен.") } })

$w.FindName("btnFolder").Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -ne "OK") { return }
    $script:Results.Clear(); Log "`r`n[>] Анализ папки: $($dlg.SelectedPath)..."; $found=$false
    Get-ChildItem $dlg.SelectedPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match $cheats) { Add-Result "Папка" $_.FullName 2; $found=$true }
        if ($_.Extension -eq ".jar") {
            try { Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip=[IO.Compression.ZipFile]::OpenRead($_.FullName); $hits=@($zip.Entries | Where-Object { $_.FullName -match $cheats }); $zip.Dispose(); if($hits.Count -gt 0){ Add-Result "JAR" "$($_.Name) -> $($hits[0].FullName)" 2; $found=$true } } catch {}
        }
    }
    if(-not $found){ Add-Result "Папка" "Чисто" 0 }
    Show-Results "Папка"
})

$w.FindName("btnAiDeep").Add_Click({
    $script:Results.Clear(); Log "`r`n[>] AI Анализ..."; $found=$false
    foreach($mc in (Get-LauncherFolders)){ $md="$mc\mods"; if(Test-Path $md){ Get-ChildItem $md -Filter *.jar | ForEach-Object { try { $zip=[IO.Compression.ZipFile]::OpenRead($_.FullName); $hits=@($zip.Entries | Where-Object { $_.FullName -match "killaura|aimbot|newlauncher|exclusion" }); $zip.Dispose(); if($hits.Count -gt 0){ Add-Result "AI" "$($_.Name) -> $($hits[0].FullName)" 2; $found=$true } } catch {} } } }
    if(-not $found){ Add-Result "AI" "Чисто" 0 }; Show-Results "AI"
})

$w.FindName("btnRemover").Add_Click({
    $rmx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'rm_title')" Height="700" Width="900" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#0A0A0A" BorderBrush="$( $script:cfg.accent )" BorderThickness="2"><Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,15"><TextBlock Text="$(L 'rm_title')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold"/>
<Button x:Name="btnRmClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,15"><Button x:Name="btnRmScan" Content="$(L 'rm_scan')" Width="130" Height="35" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" BorderThickness="0" Margin="0,0,10,0"/><Button x:Name="btnRmKill" Content="$(L 'rm_kill')" Width="130" Height="35" Background="#552200" Foreground="#FFF" FontWeight="Bold" BorderThickness="0" Margin="0,0,10,0"/><Button x:Name="btnRmSel" Content="$(L 'rm_sel')" Width="130" Height="35" Background="#333" Foreground="#FFF" FontWeight="Bold" BorderThickness="0"/></StackPanel>
<DataGrid x:Name="dgRm" Grid.Row="2" AutoGenerateColumns="False" Background="#0F0F0F" RowBackground="Transparent" AlternatingRowBackground="#151515" Foreground="$( $script:cfg.accent )" BorderThickness="0" HeadersVisibility="Column" CanUserAddRows="False" IsReadOnly="True" SelectionMode="Extended" GridLinesVisibility="None" RowHeight="25">
<DataGrid.Columns><DataGridTextColumn Header="Путь" Binding="{Binding Path}" Width="*"/><DataGridTextColumn Header="Тип" Binding="{Binding Type}" Width="80"/></DataGrid.Columns></DataGrid>
<Button x:Name="btnRmDel" Grid.Row="3" Content="$(L 'rm_del')" Height="45" Background="#AA0000" Foreground="#FFF" FontWeight="Bold" FontSize="14" BorderThickness="0" Margin="0,15,0,0"/></Grid></Border></Window>
"@
    $rw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$rmx)))
    $rw.Owner = $w; $rw.Add_MouseLeftButtonDown({ try { $rw.DragMove() } catch {} }); $rw.FindName("btnRmClose").Add_Click({ $rw.Close() })
    $script:Items = New-Object System.Collections.ArrayList
    $rw.FindName("btnRmScan").Add_Click({
        $script:Items.Clear()
        foreach($folder in (Get-LauncherFolders)){ $md="$folder\mods"; if(Test-Path $md){ Get-ChildItem $md -Filter *.jar | Where-Object { $_.Name -match $cheats } | ForEach-Object { [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="File"}) } } }
        $rw.FindName("dgRm").ItemsSource = $script:Items
    })
    $rw.FindName("btnRmKill").Add_Click({ Get-CimInstance Win32_Process | Where-Object { ($_.Name -match "java" -and $_.CommandLine -match $cheats) -or ($_.Name -match "newlauncher") } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; [Windows.MessageBox]::Show("Процессы убиты.") })
    $rw.FindName("btnRmSel").Add_Click({ $rw.FindName("dgRm").SelectAll() })
    $rw.FindName("btnRmDel").Add_Click({
        foreach($it in @($rw.FindName("dgRm").SelectedItems)){ try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($it.Path, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {} }
        $rw.FindName("btnRmScan").Invoke()
    })
    $rw.ShowDialog() | Out-Null
})

# Правила
$rulesPanel = $w.FindName("rulesPanel")
$accentBrush = [Windows.Media.BrushConverter]::new().ConvertFromString($script:cfg.accent); $grayBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#AAAAAA"); $whiteBrush = [Windows.Media.Brushes]::White
$rulesData = @"
1. Общие положения
1.1 При регистрации на сервере вы автоматически принимаете данный свод правил, а также подтверждаете своё согласие на рассылку вам рекламных сообщений.
1.2 На проекте действует прецедентная система правил. Если игрок совершил правонарушение, которое не описано ни в одном из опубликованных правил, он может быть наказан с разрешения Главной Администрации.
1.3 Незнание правил не освобождает вас от ответственности.
2. Правила чата
2.1 Запрещен Капс/Флуд/Спам в любом из чатов. | Мут 30 минут
2.2 Запрещена организация флуда / Попрошайничество в любом виде. | Мут 30 минут
2.3 Запрещено завуалированное оскорбление или упоминание родственников. | Мут 2 часа
2.4 Запрещено прямое оскорбление родителей. | Мут 4 часа
2.6 Запрещено рекламировать посторонние ресурсы. | Бан навсегда
3. Игровой процесс
3.1 Запрещена любая помеха работе администрации. | Кик или Бан на 10 минут
3.7 Запрещено использование стороннего ПО (Читы). | Бан 14 дней
4. Правила проверок
5.1 Вы обязаны выполнять требования Проверяющего. | Бан / Кик
5.6 Во время проверки запрещается удалять какие-либо файлы с ПК. | Бан / Кик
"@
foreach ($line in ($rulesData -split "`n")) {
    $line = $line.Trim(); if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $tb = New-Object Windows.Controls.TextBlock; $tb.TextWrapping = "Wrap"; $tb.Margin = "0,0,0,8"; $tb.FontFamily = "Segoe UI"
    if ($line -match '^\d+\.\s') { $tb.Text = $line.ToUpper(); $tb.Foreground = $accentBrush; $tb.FontSize = 18; $tb.FontWeight = "Bold"; $tb.Margin = "0,20,0,10" }
    elseif ($line -match '^\d+\.\d+') {
        if ($line -match '(.*?)\|(.*)') {
            $tb.Foreground = $grayBrush; $tb.FontSize = 14
            $runRule = New-Object Windows.Documents.Run($matches[1].Trim()); $runRule.Foreground = $whiteBrush
            $runPunish = New-Object Windows.Documents.Run(" |" + $matches[2]); $runPunish.Foreground = $accentBrush; $runPunish.FontWeight = "Bold"
            [void]$tb.Inlines.Add($runRule); [void]$tb.Inlines.Add($runPunish)
        } else { $tb.Text = $line; $tb.Foreground = $grayBrush; $tb.FontSize = 14 }
    } else { $tb.Text = $line; $tb.Foreground = $grayBrush; $tb.FontSize = 14 }
    [void]$rulesPanel.Children.Add($tb)
}
$w.FindName("btnSetSave").Add_Click({ $script:cfg.accent = $w.FindName("txtSetAccent").Text; $script:cfg | ConvertTo-Json | Set-Content $script:cfgPath -Encoding UTF8; [Windows.MessageBox]::Show("Сохранено! Перезапусти прогу.") })

$w.ShowDialog() | Out-Null