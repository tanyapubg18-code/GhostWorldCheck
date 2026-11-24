@echo off
setlocal
set "PS_FILE=%TEMP%\GhostWorld_Runtime.ps1"
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
    public class Native {
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);
    }
    public class Injector {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
        [DllImport("kernel32.dll")]
        public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true)]
        public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr GetModuleHandle(string lpModuleName);
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern bool CloseHandle(IntPtr hObject);

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

function Get-FileStatusText($path) {
    if (-not (Test-Path $path)) { return "Удалён" }
    if ((Get-Item $path).PSIsContainer) { return "Папка" }
    try {
        $fs = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        return "Закрыт"
    } catch {
        return "Открыт"
    }
}

$script:cfgPath = "$env:APPDATA\GhostWorld\settings.json"
$dir = Split-Path $script:cfgPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$script:cfg = @{ accent = "#00FFCC"; bg = "#0A0A0A"; font = 12 }
if (Test-Path $script:cfgPath) {
    try { $script:cfg = Get-Content $script:cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$script:lang = "EN"
try {
    $c = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
    if ($c -eq "ru") { $script:lang = "RU" }
    elseif ($c -eq "uk") { $script:lang = "UA" }
} catch {}

# === ОКНО ВЫБОРА ЯЗЫКА (Полный редизайн) ===
$lx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Language" Height="500" Width="550" Background="Transparent" WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True" ResizeMode="NoResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.4"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Window.Resources>
    <Style TargetType="Button" x:Key="LangBtn">
        <Setter Property="Background" Value="#111111"/>
        <Setter Property="Foreground" Value="$( $script:cfg.accent )"/>
        <Setter Property="FontSize" Value="16"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Margin" Value="0,0,0,12"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="border" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="1" Padding="15">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="border" Property="BorderBrush" Value="$( $script:cfg.accent )"/>
                            <Setter TargetName="border" Property="Background" Value="#1A1A1A"/>
                            <Setter Property="Effect">
                                <Setter.Value>
                                    <DropShadowEffect Color="$( $script:cfg.accent )" BlurRadius="15" ShadowDepth="0" Opacity="0.5"/>
                                </Setter.Value>
                            </Setter>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
</Window.Resources>
<Border CornerRadius="15" BorderBrush="$( $script:cfg.accent )" BorderThickness="1" Background="#080808">
    <Grid>
        <Grid.RowDefinitions><RowDefinition Height="40"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Grid Grid.Row="0" Background="Transparent">
            <Button x:Name="btnLangClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Margin="0,5,5,0" Background="Transparent" Foreground="#888" FontSize="14" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
        </Grid>
        <StackPanel Grid.Row="1" Margin="40,0,40,40" VerticalAlignment="Center">
            <TextBlock Text="GHOSTWORLD" Foreground="$( $script:cfg.accent )" FontSize="36" FontWeight="Bold" FontFamily="Segoe UI" HorizontalAlignment="Center">
                <TextBlock.Effect><DropShadowEffect Color="$( $script:cfg.accent )" BlurRadius="20" ShadowDepth="0" Opacity="0.8"/></TextBlock.Effect>
            </TextBlock>
            <TextBlock Text="v38.0" Foreground="#666" FontSize="14" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,25"/>
            <TextBlock Text="Добро пожаловать!" Foreground="#FFF" FontSize="18" FontWeight="SemiBold" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,30"/>
            <Button x:Name="btnRU" Content="Русский" Height="50" Style="{StaticResource LangBtn}"/>
            <Button x:Name="btnUA" Content="Українська" Height="50" Style="{StaticResource LangBtn}"/>
            <Button x:Name="btnEN" Content="English" Height="50" Style="{StaticResource LangBtn}"/>
        </StackPanel>
    </Grid>
</Border>
</Window>
"@
$lw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$lx)))
$lw.Add_MouseLeftButtonDown({ try{$lw.DragMove()}catch{} })
$lw.FindName("btnRU").Add_Click({ $script:lang="RU"; $lw.Close() })
$lw.FindName("btnUA").Add_Click({ $script:lang="UA"; $lw.Close() })
$lw.FindName("btnEN").Add_Click({ $script:lang="EN"; $lw.Close() })
$lw.FindName("btnLangClose").Add_Click({ $lw.Close() })
$lw.ShowDialog() | Out-Null

# Локализация
$script:T = @{
  RU = @{
    title="GhostWorld - Проверка читов"; version="ПРОВЕРКА v38.0"
    cg="🎮 MINECRAFT"; cs="🛡️ СИСТЕМА"; cp="🧠 ИНСТРУМЕНТЫ"; cd="☢️ ОПАСНАЯ ЗОНА"; cx="🚀 БЫСТРЫЙ СТАРТ"; cn="🔍 АНАЛИЗ"; cr="📜 ПРАВИЛА"
    m1="Папки Minecraft"; m2="Логи игр"; m3="Глубокая проверка"; m4="Java инжекторы"; m5="Реестр"; m6="Службы и дампы"; m7="Открыть Hosts"; m8="Макросы и USB"; m9="Планировщик задач"; m10="Цифровые подписи"; m11="AI анализаторы"; m12="Поиск Everything"; m13="Менеджер программ"; m14="ЯДЕРНОЕ УДАЛЕНИЕ"; m15="Автозапуск"; m16="ЗАПУСТИТЬ ВСЁ"; m17="Анализ папки"; m18="История"; m19="AI Глубокий анализ"; mc="Очистить консоль"
    m20="Инжект в Minecraft"; m21="Процессы (Cheat Engine)"; m22="Недавние файлы"; m23="Установленные программы"
    rules_btn="Открыть правила"; rules_title="Правила проекта"
    set_t="Настройки"; set_accent="Цвет акцента (HEX):"; set_bg="Цвет фона (HEX):"; set_font="Размер шрифта:"; set_save="СОХРАНИТЬ"; set_restart="Требуется перезапуск для полного применения."
    r_ready="Готово."; r_title="РЕЗУЛЬТАТЫ"; r_ok="ЧИСТО"; r_warn="ВНИМАНИЕ"; r_cheat="ЧИТ"; r_sum="Чисто: {0} | Внимание: {1} | Читы: {2}"; r_okbtn="ОК"; r_save="СОХРАНИТЬ"; r_copy="КОПИРОВАТЬ"; r_saved="Отчёт сохранён"; r_copied="Скопировано"
    rm_title="УДАЛЕНИЕ"; rm_sub="Удаляет читы в Корзину"; rm_scan="СКАНИРОВАТЬ"; rm_kill="УБИТЬ"; rm_sel="ВЫБРАТЬ ВСЁ"; rm_del="УДАЛИТЬ"; rm_ready="Нажмите СКАНИРОВАТЬ"; rm_scanning="Сканирую..."; rm_found="Найдено: {0}"; rm_none="Чисто."; rm_killing="Убиваю..."; rm_killed="Убито: {0}"; rm_conf_t="Вопрос"; rm_conf_m="Удалить {0}?"; rm_done_t="Готово"; rm_done_m="Удалено: {0}, Ошибок: {1}"
    rm_col_found="НАЙДЕНО:"; rm_col_del="УДАЛЕНО:"; rm_del_empty="Пока пусто"
    tools_t="Менеджер"; tools_sel="Программы"; tools_dl="СКАЧАТЬ"; tools_ready="Выберите и скачайте."; tools_proc="Качаю..."; tools_done="Готово!"; tools_done_m="Проверьте рабочий стол."; tools_nosel="Ничего не выбрано"; tools_result="Итог"; tools_folder="Папка"; tools_total="Итого"; tools_ok="OK"; tools_fail="ОШИБКА"; tools_dl_ing="Качаю"
    folder_t="Анализ папки"; folder_pick="ВЫБРАТЬ"; folder_scan="АНАЛИЗ"; folder_none="Не выбрана"; folder_scanning="Сканирую..."; folder_done="Готово"; folder_noitems="Чисто"; folder_found="Найдено: {0}"; folder_browse="Папка"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR архив"; folder_scan_sub="Подпапки"
    hist_t="История"; hist_empty="Пусто"; hist_clear="ОЧИСТИТЬ"; hist_items="{0} записей"; hist_del_confirm="Очистить?"; hist_view="Открыть"
    close="✕"; min="—"; max="□"
    cat_mod="Чит-мод"; cat_lib="Библиотека"; cat_ver="Версия"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Ярлык"; cat_temp="Temp"; cat_dl="Загрузки"; cat_autorun="Автозапуск"; cat_folder="Папка"; cat_jar="JAR"; cat_ai="AI"
    log_mods="Моды..."; log_mods_ok="Чисто."
    log_logs="Логи..."; log_logs_ok="Чисто."
    log_deep="Глубокая..."; log_deep_ok="Чисто."
    log_java="Java..."; log_java_ok="Чисто."
    log_reg="Реестр..."; log_reg_ok="Чисто."
    log_sys="Службы..."; log_sys_ok="Всё ОК."
    log_hosts="Hosts..."
    log_macro="Макросы..."; log_macro_ok="Чисто."; log_usb="USB..."
    log_task="Таски..."; log_task_ok="Чисто."
    log_sig="Подписи..."; log_sig_ok="ОК."
    log_ai="AI..."; log_every="Everything..."; log_every_miss="Нет."
    log_autorun="Автозапуск..."; log_autorun_ok="Чисто."
    log_all="ВСЁ..."
    log_inject="Инжект..."; log_shift="Нажат Правый Shift! Проверяю Minecraft..."
    log_procs="Процессы..."; log_installed="Установленные программы..."
    ai_deep_scanning="Глубокий анализ..."; ai_deep_none="Чисто."
  }
  UA = @{
    title="GhostWorld - Перевірка читів"; version="ПЕРЕВІРКА v38.0"
    cg="🎮 MINECRAFT"; cs="🛡️ СИСТЕМА"; cp="🧠 ІНСТРУМЕНТИ"; cd="☢️ НЕБЕЗПЕКА"; cx="🚀 ШВИДКИЙ СТАРТ"; cn="🔍 АНАЛІЗ"; cr="📜 ПРАВИЛА"
    m1="Папки Minecraft"; m2="Логи ігор"; m3="Глибока перевірка"; m4="Java інжектори"; m5="Реєстр"; m6="Служби"; m7="Hosts"; m8="Макроси"; m9="Планувальник"; m10="Підписи"; m11="AI"; m12="Everything"; m13="Менеджер"; m14="ВИДАЛЕННЯ"; m15="Автозапуск"; m16="ЗАПУСТИТИ ВСЕ"; m17="Аналіз папки"; m18="Історія"; m19="AI Аналіз"; mc="Очистити"
    m20="Інжект в Minecraft"; m21="Процеси (Cheat Engine)"; m22="Недавні файли"; m23="Встановлені програми"
    rules_btn="Відкрити правила"; rules_title="Правила проекту"
    set_t="Налаштування"; set_accent="Колір акценту (HEX):"; set_bg="Колір фону (HEX):"; set_font="Розмір шрифту:"; set_save="ЗБЕРЕГТИ"; set_restart="Потрібен перезапуск."
    r_ready="Готово."; r_title="РЕЗУЛЬТАТИ"; r_ok="ЧИСТО"; r_warn="УВАГА"; r_cheat="ЧИТ"; r_sum="Чисто: {0} | Увага: {1} | Чити: {2}"; r_okbtn="ОК"; r_save="ЗБЕРЕГТИ"; r_copy="КОПІЮВАТИ"; r_saved="Збережено"; r_copied="Скопійовано"
    rm_title="ВИДАЛЕННЯ"; rm_sub="Видаляє в Кошик"; rm_scan="СКАНУВАТИ"; rm_kill="ВБИТИ"; rm_sel="ВСЕ"; rm_del="ВИДАЛИТИ"; rm_ready="Натисніть СКАНУВАТИ"; rm_scanning="Сканую..."; rm_found="Знайдено: {0}"; rm_none="Чисто."; rm_killing="Вбиваю..."; rm_killed="Вбито: {0}"; rm_conf_t="Питання"; rm_conf_m="Видалити {0}?"; rm_done_t="Готово"; rm_done_m="Видалено: {0}, Помилок: {1}"
    rm_col_found="ЗНАЙДЕНО:"; rm_col_del="ВИДАЛЕНО:"; rm_del_empty="Поки пусто"
    tools_t="Менеджер"; tools_sel="Програми"; tools_dl="ЗАВАНТАЖИТИ"; tools_ready="Оберіть."; tools_proc="Качаю..."; tools_done="Готово!"; tools_done_m="Перевірте стіл."; tools_nosel="Нічого"; tools_result="Підсумок"; tools_folder="Папка"; tools_total="Разом"; tools_ok="OK"; tools_fail="ПОМИЛКА"; tools_dl_ing="Качаю"
    folder_t="Аналіз папки"; folder_pick="ОБРАТИ"; folder_scan="АНАЛІЗ"; folder_none="Не обрана"; folder_scanning="Сканую..."; folder_done="Готово"; folder_noitems="Чисто"; folder_found="Знайдено: {0}"; folder_browse="Папка"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR"; folder_scan_sub="Підпапки"
    hist_t="Історія"; hist_empty="Порожньо"; hist_clear="ОЧИСТИТИ"; hist_items="{0} записів"; hist_del_confirm="Очистити?"; hist_view="Відкрити"
    close="✕"; min="—"; max="□"
    cat_mod="Чит-мод"; cat_lib="Бібліотека"; cat_ver="Версія"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Ярлик"; cat_temp="Temp"; cat_dl="Завантаження"; cat_autorun="Автозапуск"; cat_folder="Папка"; cat_jar="JAR"; cat_ai="AI"
    log_mods="Моди..."; log_mods_ok="Чисто."
    log_logs="Логи..."; log_logs_ok="Чисто."
    log_deep="Глибока..."; log_deep_ok="Чисто."
    log_java="Java..."; log_java_ok="Чисто."
    log_reg="Реєстр..."; log_reg_ok="Чисто."
    log_sys="Служби..."; log_sys_ok="Все ОК."
    log_hosts="Hosts..."
    log_macro="Макроси..."; log_macro_ok="Чисто."; log_usb="USB..."
    log_task="Таски..."; log_task_ok="Чисто."
    log_sig="Підписи..."; log_sig_ok="ОК."
    log_ai="AI..."; log_every="Everything..."; log_every_miss="Немає."
    log_autorun="Автозапуск..."; log_autorun_ok="Чисто."
    log_all="ВСЕ..."
    log_inject="Інжект..."; log_shift="Правий Shift! Перевіряю Minecraft..."
    log_procs="Процеси..."; log_installed="Встановлені програми..."
    ai_deep_scanning="Глибокий аналіз..."; ai_deep_none="Чисто."
  }
  EN = @{
    title="GhostWorld - Cheat Checker"; version="CHECKER v38.0"
    cg="🎮 MINECRAFT"; cs="🛡️ SYSTEM"; cp="🧠 TOOLS"; cd="☢️ DANGER ZONE"; cx="🚀 QUICK START"; cn="🔍 ANALYSIS"; cr="📜 RULES"
    m1="Minecraft Folders"; m2="Game Logs"; m3="Deep Scan"; m4="Java Injectors"; m5="Registry"; m6="Services and Dumps"; m7="Open Hosts"; m8="Macro and USB"; m9="Task Scheduler"; m10="Signatures"; m11="AI Analyzers"; m12="Everything Search"; m13="Tools Manager"; m14="NUCLEAR REMOVE"; m15="Autostart"; m16="RUN ALL SCANS"; m17="Folder Analysis"; m18="History"; m19="AI Deep Scan"; mc="Clear Console"
    m20="Inject into Minecraft"; m21="Processes (Cheat Engine)"; m22="Recent Files"; m23="Installed Programs"
    rules_btn="Open Rules"; rules_title="Project Rules"
    set_t="Settings"; set_accent="Accent Color (HEX):"; set_bg="Background Color (HEX):"; set_font="Font Size:"; set_save="SAVE"; set_restart="Restart required to apply fully."
    r_ready="Ready."; r_title="RESULTS"; r_ok="CLEAN"; r_warn="SUSPICIOUS"; r_cheat="CHEAT"; r_sum="Clean: {0} | Suspicious: {1} | Cheats: {2}"; r_okbtn="OK"; r_save="SAVE"; r_copy="COPY"; r_saved="Saved"; r_copied="Copied"
    rm_title="REMOVER"; rm_sub="Deletes cheats to Recycle Bin"; rm_scan="SCAN"; rm_kill="KILL"; rm_sel="SELECT ALL"; rm_del="DELETE"; rm_ready="Click SCAN"; rm_scanning="Scanning..."; rm_found="Found: {0}"; rm_none="Clean."; rm_killing="Killing..."; rm_killed="Killed: {0}"; rm_conf_t="Confirm"; rm_conf_m="Delete {0}?"; rm_done_t="Done"; rm_done_m="Deleted: {0}, Failed: {1}"
    rm_col_found="FOUND:"; rm_col_del="DELETED:"; rm_del_empty="Empty"
    tools_t="Tools"; tools_sel="Programs"; tools_dl="DOWNLOAD"; tools_ready="Select and download."; tools_proc="Downloading..."; tools_done="Done!"; tools_done_m="Check Desktop."; tools_nosel="Nothing selected"; tools_result="Result"; tools_folder="Folder"; tools_total="Total"; tools_ok="OK"; tools_fail="FAIL"; tools_dl_ing="Downloading"
    folder_t="Folder Analysis"; folder_pick="PICK"; folder_scan="ANALYZE"; folder_none="Not selected"; folder_scanning="Scanning..."; folder_done="Done"; folder_noitems="Clean"; folder_found="Found: {0}"; folder_browse="Folder"; folder_scan_all=".jar/.exe/.dll"; folder_scan_deep="JAR content"; folder_scan_sub="Subfolders"
    hist_t="History"; hist_empty="Empty"; hist_clear="CLEAR"; hist_items="{0} records"; hist_del_confirm="Clear?"; hist_view="View"
    close="✕"; min="—"; max="□"
    cat_mod="Cheat Mod"; cat_lib="Library"; cat_ver="Version"; cat_appdata="AppData"; cat_newlauncher="NewLauncher"; cat_exclusion="Exclusion"; cat_sc="Shortcut"; cat_temp="Temp"; cat_dl="Downloads"; cat_autorun="Autostart"; cat_folder="Folder"; cat_jar="JAR"; cat_ai="AI"
    log_mods="Mods..."; log_mods_ok="Clean."
    log_logs="Logs..."; log_logs_ok="Clean."
    log_deep="Deep..."; log_deep_ok="Clean."
    log_java="Java..."; log_java_ok="Clean."
    log_reg="Registry..."; log_reg_ok="Clean."
    log_sys="Services..."; log_sys_ok="All OK."
    log_hosts="Hosts..."
    log_macro="Macro..."; log_macro_ok="Clean."; log_usb="USB..."
    log_task="Tasks..."; log_task_ok="Clean."
    log_sig="Signatures..."; log_sig_ok="OK."
    log_ai="AI..."; log_every="Everything..."; log_every_miss="Not installed."
    log_autorun="Autostart..."; log_autorun_ok="Clean."
    log_all="ALL..."
    log_inject="Injecting..."; log_shift="Right Shift pressed! Checking Minecraft..."
    log_procs="Processes..."; log_installed="Installed programs..."
    ai_deep_scanning="Deep scan..."; ai_deep_none="Clean."
  }
}
function L([string]$k) { try { $v=$script:T[$script:lang][$k]; if($null -eq $v){return $k}; return [string]$v } catch { return $k } }

$cheats = "impact|wurst|aristois|baritone|liquidbounce|rusherhack|future|konas|salhack|kamiblue|sigma|vape|novoline|tenacity|rise|astolfo|krypton|moonproject|akrien|celestial|forgehax|inertia|wexside|wolfram|bleach|pyro|jigsaw|candycrack|flux|nurik|minced|nightmare|augustus|thunderhack|fatal|resolute|centric|delta|catlavan|quick|dimasik|skycor|energy|norules|matix|deadcode|eternity|rich|editme|mc100|r3d|wild|boberware|cortex|wex|hitbox|fluger|jessica|freecam|inventorytotem|chestlocator|valex|fabaritone|crack|celka|keazclient|tofficlient|darkness|archware|intave|nova|haramdev|shitclient|ponosclient|vegaline|newlight|exclusive|tenseclient|moonhack|deltaclient|hachclient|fullmyst|gothaj|sirius|wave|veristclient|avalon|wissendfree|resolutefree|kwishfree|centricfree|tutotialclient|fecuritysq|noclips|koshkadlc|flauncher|atmosphere|hider|huzuni|neverhook|exloader|calestial|clowdyclient|vert|vapeclient|clownclient|norender|extremehack|asteria|aimmbot|elytra_swap|smart_moving|chest_stealer|topkaautobuy|doomsday|viaversion|viamcp|spambot|xray|x-ray|killaura|wallhack|aimbot|newlauncher|new_launcher|new-launcher|exclusion|exclusionlauncher|exclusion_launcher|exclusion-launcher"

$badProcs = "cheatengine|processhacker|x64dbg|ollydbg|ida64|wireshark|fiddler|dnspy|extremeinjector|xenos|scylla|artmoney|hxd"
$badApps = "Cheat Engine|Process Hacker|HxD|DB Browser|Wireshark|x64dbg|OllyDbg|IDA Pro|Scylla|Extreme Injector|Fiddler|Charles|ArtMoney|SAO Utils"

function Get-LauncherFolders {
    @(
        "$env:APPDATA\.minecraft","$env:APPDATA\.tlauncher","$env:APPDATA\TLauncher",
        "$env:APPDATA\MultiMC","$env:APPDATA\PrismLauncher","$env:APPDATA\.lunarclient",
        "$env:APPDATA\.badlion","$env:APPDATA\.feather","$env:APPDATA\.salwyrr",
        "$env:APPDATA\.newlauncher","$env:APPDATA\NewLauncher","$env:LOCALAPPDATA\NewLauncher",
        "$env:LOCALAPPDATA\.newlauncher","$env:APPDATA\.exclusion","$env:APPDATA\Exclusion",
        "$env:LOCALAPPDATA\Exclusion","$env:USERPROFILE\.minecraft"
    ) | Where-Object { Test-Path $_ } | Select-Object -Unique
}

$histDir = "$env:APPDATA\GhostWorld"
if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Path $histDir -Force | Out-Null }
$histFile = Join-Path $histDir "history.json"

function Save-History($scanType) {
    try {
        $entry = [PSCustomObject]@{
            time = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            type = $scanType
            ok = @($script:Results | Where-Object { $_.Sev -eq 0 }).Count
            warn = @($script:Results | Where-Object { $_.Sev -eq 1 }).Count
            cheat = @($script:Results | Where-Object { $_.Sev -eq 2 }).Count
            items = @($script:Results | Select-Object Cat, Text, Sev)
        }
        $all = @()
        if (Test-Path $histFile) {
            try { $all = @(Get-Content $histFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $all = @() }
        }
        $all = @($entry) + $all
        if ($all.Count -gt 100) { $all = $all[0..99] }
        $all | ConvertTo-Json -Depth 5 | Set-Content $histFile -Encoding UTF8
    } catch {}
}

# Основное окно (Добавлен кастомный ScrollBar)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'title')" Height="900" Width="1180" MinHeight="600" MinWidth="900" Background="Transparent" WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard>
<DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.4"/>
<DoubleAnimation Storyboard.TargetName="LeftPanel" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" From="-200" To="0" Duration="0:0:0.6"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
<DoubleAnimation Storyboard.TargetName="LeftPanel" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.6"/>
<DoubleAnimation Storyboard.TargetName="RightPanel" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.8"/>
</Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Window.Resources>
<!-- Стиль для кастомного скроллбара -->
<Style TargetType="{x:Type ScrollBar}">
    <Setter Property="Width" Value="8"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="{x:Type ScrollBar}">
                <Grid Background="{TemplateBinding Background}" Margin="2,0">
                    <Track x:Name="PART_Track" IsDirectionReversed="True">
                        <Track.DecreaseRepeatButton>
                            <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                        </Track.DecreaseRepeatButton>
                        <Track.Thumb>
                            <Thumb>
                                <Thumb.Template>
                                    <ControlTemplate TargetType="{x:Type Thumb}">
                                        <Border x:Name="thumbBorder" Background="#333" CornerRadius="4" Opacity="0.8"/>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="thumbBorder" Property="Background" Value="$( $script:cfg.accent )"/>
                                                <Setter TargetName="thumbBorder" Property="Opacity" Value="1"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </Thumb.Template>
                            </Thumb>
                        </Track.Thumb>
                        <Track.IncreaseRepeatButton>
                            <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                        </Track.IncreaseRepeatButton>
                    </Track>
                </Grid>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>

<Style TargetType="Button" x:Key="MenuBtn">
<Setter Property="Background" Value="#151515"/><Setter Property="Foreground" Value="$( $script:cfg.accent )"/><Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="12"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Margin" Value="0,3"/><Setter Property="Cursor" Value="Hand"/>
<Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="1" Padding="10,7"><ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/></Border>
<ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A2A2A"/><Setter TargetName="b" Property="BorderBrush" Value="$( $script:cfg.accent )"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>

<Style TargetType="Button" x:Key="CloseBtn">
<Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="#888"/><Setter Property="FontSize" Value="16"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Cursor" Value="Hand"/>
<Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="10" Background="{TemplateBinding Background}" Width="30" Height="30"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
<ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FF3333"/><Setter Property="Foreground" Value="#FFF"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>

<Style TargetType="TextBox" x:Key="ConsoleBox">
<Setter Property="Background" Value="#050505"/><Setter Property="Foreground" Value="#00FF00"/><Setter Property="FontFamily" Value="Consolas"/><Setter Property="FontSize" Value="12"/><Setter Property="IsReadOnly" Value="True"/>
<Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><Border CornerRadius="12" Background="{TemplateBinding Background}" BorderBrush="#222" BorderThickness="1"><ScrollViewer x:Name="PART_ContentHost" Margin="15" VerticalScrollBarVisibility="Auto"/></Border></ControlTemplate></Setter.Value></Setter></Style>

<Style TargetType="Expander" x:Key="Accordion">
<Setter Property="Foreground" Value="$( $script:cfg.accent )"/>
<Setter Property="FontFamily" Value="Segoe UI"/>
<Setter Property="FontWeight" Value="Bold"/>
<Setter Property="FontSize" Value="11"/>
<Setter Property="Margin" Value="0,4,0,2"/>
<Setter Property="Template">
<Setter.Value>
<ControlTemplate TargetType="Expander">
<StackPanel>
<ToggleButton x:Name="HeaderSite" Content="{TemplateBinding Header}" IsChecked="{Binding IsExpanded, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}" Cursor="Hand" Background="Transparent" BorderThickness="0">
<ToggleButton.Template>
<ControlTemplate TargetType="ToggleButton">
<Grid Background="Transparent" Margin="0,4">
<Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<Border Grid.Column="0" Height="1" Background="#444" Width="15" VerticalAlignment="Center"/>
<StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Center">
<TextBlock x:Name="Arrow" Text="&#9654;" Foreground="#888" FontSize="9" Margin="0,0,6,0" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5"><TextBlock.RenderTransform><RotateTransform Angle="0"/></TextBlock.RenderTransform></TextBlock>
<TextBlock x:Name="Txt" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" FontWeight="Bold" VerticalAlignment="Center"/>
</StackPanel>
<Border Grid.Column="2" Height="1" Background="#444" Width="15" VerticalAlignment="Center"/>
</Grid>
<ControlTemplate.Triggers>
<Trigger Property="IsChecked" Value="True"><Setter TargetName="Arrow" Property="RenderTransform"><Setter.Value><RotateTransform Angle="90"/></Setter.Value></Setter><Setter TargetName="Txt" Property="Foreground" Value="$( $script:cfg.accent )"/></Trigger>
<Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Txt" Property="Foreground" Value="#FFF"/><Setter TargetName="Arrow" Property="Foreground" Value="#FFF"/></Trigger>
</ControlTemplate.Triggers>
</ControlTemplate>
</ToggleButton.Template>
</ToggleButton>
<ContentPresenter x:Name="ExpandSite" Visibility="Collapsed" Margin="15,2,0,8"><ContentPresenter.RenderTransform><TranslateTransform Y="-15"/></ContentPresenter.RenderTransform></ContentPresenter>
</StackPanel>
<ControlTemplate.Triggers>
<Trigger Property="IsExpanded" Value="True">
<Setter TargetName="ExpandSite" Property="Visibility" Value="Visible"/>
<Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ExpandSite" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.25"/><DoubleAnimation Storyboard.TargetName="ExpandSite" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" From="-15" To="0" Duration="0:0:0.25"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
</Trigger>
</ControlTemplate.Triggers>
</ControlTemplate>
</Setter.Value>
</Setter>
</Style>
</Window.Resources>

<Border x:Name="mainBorder" CornerRadius="15" BorderBrush="#222" BorderThickness="1" Background="#0A0A0A">
<Grid>
<Grid.RowDefinitions><RowDefinition Height="45"/><RowDefinition Height="*"/></Grid.RowDefinitions>
<Grid x:Name="TitleBar" Grid.Row="0" Background="Transparent">
<TextBlock Text="GHOSTWORLD" Foreground="$( $script:cfg.accent )" FontSize="16" FontWeight="Bold" FontFamily="Segoe UI" Margin="20,0,0,0" VerticalAlignment="Center">
<TextBlock.Effect><DropShadowEffect x:Name="logoGlow" Color="$( $script:cfg.accent )" BlurRadius="10" ShadowDepth="0" Opacity="0.6"/></TextBlock.Effect>
</TextBlock>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,10,0">
<Button x:Name="btnSettings" Content="⚙" Style="{StaticResource CloseBtn}" FontSize="14" ToolTip="$(L 'set_t')"/>
<Button x:Name="btnMin" Content="$(L 'min')" Style="{StaticResource CloseBtn}"/>
<Button x:Name="btnMax" Content="$(L 'max')" Style="{StaticResource CloseBtn}"/>
<Button x:Name="btnClose" Content="$(L 'close')" Style="{StaticResource CloseBtn}"/>
</StackPanel>
</Grid>

<Grid Grid.Row="1">
<Grid.ColumnDefinitions><ColumnDefinition Width="320"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<Border x:Name="LeftPanel" Grid.Column="0" Background="#101010" CornerRadius="0,0,0,15" BorderBrush="#222" BorderThickness="0,1,1,0" Opacity="0">
<Border.RenderTransform><TranslateTransform X="-200"/></Border.RenderTransform>
<ScrollViewer VerticalScrollBarVisibility="Auto" Margin="20,10,10,20">
<StackPanel>
<TextBlock Text="$(L 'version')" Foreground="#666" FontSize="12" FontFamily="Segoe UI" HorizontalAlignment="Center" Margin="0,0,0,15"/>
<Expander Header="$(L 'cx')" IsExpanded="True" Style="{StaticResource Accordion}">
<StackPanel><Button x:Name="btnRunAll" Content="$(L 'm16')" Style="{StaticResource MenuBtn}" Foreground="$( $script:cfg.accent )" RenderTransformOrigin="0.5,0.5"><Button.RenderTransform><ScaleTransform x:Name="runAllScale" ScaleX="1" ScaleY="1"/></Button.RenderTransform></Button></StackPanel>
</Expander>
<Expander Header="$(L 'cg')" IsExpanded="True" Style="{StaticResource Accordion}">
<StackPanel>
<Button x:Name="btnInject" Content="$(L 'm20')" Style="{StaticResource MenuBtn}" FontWeight="Bold"/>
<Button x:Name="btnScanMods" Content="$(L 'm1')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnScanLogs" Content="$(L 'm2')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnDeepScan" Content="$(L 'm3')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnScanJava" Content="$(L 'm4')" Style="{StaticResource MenuBtn}"/>
</StackPanel>
</Expander>
<Expander Header="$(L 'cn')" IsExpanded="True" Style="{StaticResource Accordion}">
<StackPanel>
<Button x:Name="btnFolder" Content="$(L 'm17')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnHistory" Content="$(L 'm18')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnAiDeep" Content="$(L 'm19')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnRecent" Content="$(L 'm22')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnInstalled" Content="$(L 'm23')" Style="{StaticResource MenuBtn}"/>
</StackPanel>
</Expander>
<Expander Header="$(L 'cr')" IsExpanded="False" Style="{StaticResource Accordion}">
<StackPanel><Button x:Name="btnRules" Content="$(L 'rules_btn')" Style="{StaticResource MenuBtn}"/></StackPanel>
</Expander>
<Expander Header="$(L 'cs')" IsExpanded="False" Style="{StaticResource Accordion}">
<StackPanel>
<Button x:Name="btnProcs" Content="$(L 'm21')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnScanReg" Content="$(L 'm5')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnScanSys" Content="$(L 'm6')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnScanNet" Content="$(L 'm7')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnAutoRun" Content="$(L 'm15')" Style="{StaticResource MenuBtn}"/>
</StackPanel>
</Expander>
<Expander Header="$(L 'cp')" IsExpanded="False" Style="{StaticResource Accordion}">
<StackPanel>
<Button x:Name="btnMacroScan" Content="$(L 'm8')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnTaskSched" Content="$(L 'm9')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnSigCheck" Content="$(L 'm10')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnAI" Content="$(L 'm11')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnEverything" Content="$(L 'm12')" Style="{StaticResource MenuBtn}"/>
<Button x:Name="btnTools" Content="$(L 'm13')" Style="{StaticResource MenuBtn}"/>
</StackPanel>
</Expander>
<Expander Header="$(L 'cd')" IsExpanded="False" Style="{StaticResource Accordion}" Foreground="$( $script:cfg.accent )">
<StackPanel><Button x:Name="btnRemover" Content="$(L 'm14')" Style="{StaticResource MenuBtn}" Foreground="$( $script:cfg.accent )"/></StackPanel>
</Expander>
<Button x:Name="btnClear" Content="$(L 'mc')" Style="{StaticResource MenuBtn}" Margin="0,20,0,5" Foreground="#888"/>
</StackPanel>
</ScrollViewer></Border>

<Grid x:Name="RightPanel" Grid.Column="1" Opacity="0" Margin="20,10,20,20">
<Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="30"/></Grid.RowDefinitions>
<TextBox x:Name="txtConsole" Grid.Row="0" Style="{StaticResource ConsoleBox}"/>
<TextBlock x:Name="txtStatus" Grid.Row="1" Text="$(L 'r_ready')" Foreground="#888" FontFamily="Segoe UI" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Right" Margin="0,5,10,0"/>
</Grid>
<Thumb x:Name="rszMain" Width="15" Height="15" HorizontalAlignment="Right" VerticalAlignment="Bottom" Cursor="SizeNWSE" Panel.ZIndex="1000"/>
</Grid>
</Grid></Border></Window>
"@

$w = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$xaml)))
$w.Add_MouseLeftButtonDown({ 
    param($sender, $e)
    if ($e.ClickCount -eq 2) { 
        if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $w.WindowState = [Windows.WindowState]::Normal } 
        else { $w.WindowState = [Windows.WindowState]::Maximized } 
    } else { 
        try { $w.DragMove() } catch {} 
    } 
})

$mainBorder = $w.FindName("mainBorder")
$w.Add_StateChanged({
    if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $mainBorder.CornerRadius = "0" }
    else { $mainBorder.CornerRadius = "15" }
})

$txtConsole = $w.FindName("txtConsole"); $txtStatus = $w.FindName("txtStatus")
$btnClose = $w.FindName("btnClose"); $btnMin = $w.FindName("btnMin"); $btnMax = $w.FindName("btnMax"); $btnSettings = $w.FindName("btnSettings")
$btnScanMods = $w.FindName("btnScanMods"); $btnScanLogs = $w.FindName("btnScanLogs"); $btnDeepScan = $w.FindName("btnDeepScan")
$btnScanJava = $w.FindName("btnScanJava"); $btnScanReg = $w.FindName("btnScanReg"); $btnScanSys = $w.FindName("btnScanSys"); $btnScanNet = $w.FindName("btnScanNet")
$btnMacroScan = $w.FindName("btnMacroScan"); $btnTaskSched = $w.FindName("btnTaskSched"); $btnSigCheck = $w.FindName("btnSigCheck")
$btnAI = $w.FindName("btnAI"); $btnEverything = $w.FindName("btnEverything"); $btnTools = $w.FindName("btnTools")
$btnRemover = $w.FindName("btnRemover"); $btnClear = $w.FindName("btnClear"); $btnAutoRun = $w.FindName("btnAutoRun"); $btnRunAll = $w.FindName("btnRunAll")
$btnFolder = $w.FindName("btnFolder"); $btnHistory = $w.FindName("btnHistory"); $btnAiDeep = $w.FindName("btnAiDeep")
$btnInject = $w.FindName("btnInject"); $btnProcs = $w.FindName("btnProcs"); $btnRecent = $w.FindName("btnRecent"); $btnInstalled = $w.FindName("btnInstalled")
$btnRules = $w.FindName("btnRules")
$rszMain = $w.FindName("rszMain")
$runAllScale = $w.FindName("runAllScale")
$logoGlow = $w.FindName("logoGlow")

$rszMain.Add_DragDelta({
    $nw = $w.Width + $_.HorizontalChange
    $nh = $w.Height + $_.VerticalChange
    if ($nw -ge $w.MinWidth) { $w.Width = $nw }
    if ($nh -ge $w.MinHeight) { $w.Height = $nh }
})

$logoAnim = New-Object Windows.Media.Animation.DoubleAnimation
$logoAnim.From = 0.6; $logoAnim.To = 1.0; $logoAnim.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds(1.5))
$logoAnim.AutoReverse = $true; $logoAnim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
$logoGlow.BeginAnimation([Windows.Media.Effects.DropShadowEffect]::OpacityProperty, $logoAnim)

$runAllAnim = New-Object Windows.Media.Animation.DoubleAnimation
$runAllAnim.From = 1.0; $runAllAnim.To = 1.03; $runAllAnim.Duration = [Windows.Duration]::new([TimeSpan]::FromSeconds(1))
$runAllAnim.AutoReverse = $true; $runAllAnim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
$runAllScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $runAllAnim)
$runAllScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $runAllAnim)

$btnClose.Add_Click({ $w.Close() })
$btnMin.Add_Click({ $w.WindowState = [Windows.WindowState]::Minimized })
$btnMax.Add_Click({
    if ($w.WindowState -eq [Windows.WindowState]::Maximized) { $w.WindowState = [Windows.WindowState]::Normal }
    else { $w.WindowState = [Windows.WindowState]::Maximized }
})

# === НАСТРОЙКИ ===
$btnSettings.Add_Click({
    $sx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'set_t')" Height="400" Width="350" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="NoResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#0A0A0A" BorderBrush="$( $script:cfg.accent )" BorderThickness="2">
<Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,15"><TextBlock Text="$(L 'set_t')" Foreground="$( $script:cfg.accent )" FontSize="20" FontWeight="Bold" FontFamily="Segoe UI"/>
<Button x:Name="btnSClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="1">
<TextBlock Text="$(L 'set_accent')" Foreground="#CCC" FontSize="12" Margin="0,0,0,5"/>
<TextBox x:Name="txtAccent" Text="$( $script:cfg.accent )" Background="#151515" Foreground="#FFF" FontSize="14" Padding="8" Margin="0,0,0,15" BorderThickness="1" BorderBrush="#333"/>
<TextBlock Text="$(L 'set_bg')" Foreground="#CCC" FontSize="12" Margin="0,0,0,5"/>
<TextBox x:Name="txtBg" Text="$( $script:cfg.bg )" Background="#151515" Foreground="#FFF" FontSize="14" Padding="8" Margin="0,0,0,15" BorderThickness="1" BorderBrush="#333"/>
<TextBlock Text="$(L 'set_font')" Foreground="#CCC" FontSize="12" Margin="0,0,0,5"/>
<Slider x:Name="sldFont" Minimum="10" Maximum="20" Value="$( $script:cfg.font )" TickFrequency="1" IsSnapToTickEnabled="True" Margin="0,0,0,5"/>
<TextBlock Text="$(L 'set_restart')" Foreground="#FF5555" FontSize="11" Margin="0,10,0,0" TextWrapping="Wrap"/>
</StackPanel>
<Button x:Name="btnSSave" Grid.Row="2" Content="$(L 'set_save')" Height="40" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,10,0,0"/>
</Grid></Border></Window>
"@
    $sw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$sx)))
    $sw.Owner = $w; $sw.Add_MouseLeftButtonDown({ try { $sw.DragMove() } catch {} })
    $sw.FindName("btnSClose").Add_Click({ $sw.Close() })
    $sw.FindName("btnSSave").Add_Click({
        $script:cfg.accent = $sw.FindName("txtAccent").Text
        $script:cfg.bg = $sw.FindName("txtBg").Text
        $script:cfg.font = [int]$sw.FindName("sldFont").Value
        $script:cfg | ConvertTo-Json | Set-Content $script:cfgPath -Encoding UTF8
        [Windows.MessageBox]::Show("Сохранено! Перезапусти чекер.", "GhostWorld")
        $sw.Close()
    })
    $sw.ShowDialog() | Out-Null
})

function Log($m) { $txtConsole.AppendText("$m`r`n"); $txtConsole.ScrollToEnd() }
function SetStatus($m) { $txtStatus.Text = $m }

$script:statusAnimBase = ""
$script:statusAnimOn = $false
$script:statusDots = 0
$statusTimer = New-Object Windows.Threading.DispatcherTimer
$statusTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$statusTimer.Add_Tick({
    if ($script:statusAnimOn) {
        $script:statusDots = ($script:statusDots + 1) % 4
        $txtStatus.Text = $script:statusAnimBase + ("." * $script:statusDots)
    }
})
function SetStatusAnimated($m) { $script:statusAnimBase = $m; $script:statusAnimOn = $true; $script:statusDots = 0; $txtStatus.Text = $m; if (-not $statusTimer.IsEnabled) { $statusTimer.Start() } }
function StopStatusAnimated() { $script:statusAnimOn = $false; $statusTimer.Stop(); $txtStatus.Text = $script:statusAnimBase }

$script:Results = New-Object System.Collections.ArrayList
function Add-Result($cat, $txt, $sev) { [void]$script:Results.Add([PSCustomObject]@{Cat=$cat;Text=$txt;Sev=$sev}) }

function Show-Results($scanType) {
    $rx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'r_title')" Height="720" Width="1050" MinHeight="400" MinWidth="650" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard>
<DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.35"/>
<DoubleAnimation Storyboard.TargetName="resBorder" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" From="40" To="0" Duration="0:0:0.4"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
</Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border x:Name="resBorder" CornerRadius="15" Background="#0A0A0A" BorderBrush="#333" BorderThickness="1">
<Border.RenderTransform><TranslateTransform Y="40"/></Border.RenderTransform>
<Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,10"><TextBlock Text="$(L 'r_title')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold" FontFamily="Segoe UI"/>
<Button x:Name="btnResClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,15">
<Border Background="#003300" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_ok')" Foreground="#00FF88" FontWeight="Bold"/></Border>
<Border Background="#332200" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_warn')" Foreground="#FFCC00" FontWeight="Bold"/></Border>
<Border Background="#330000" CornerRadius="5" Padding="10,5" Margin="0,0,10,0"><TextBlock Text="$(L 'r_cheat')" Foreground="#FF4444" FontWeight="Bold"/></Border></StackPanel>
<Border Grid.Row="2" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="0">
<DataGrid x:Name="dgResults" AutoGenerateColumns="False" Background="Transparent" RowBackground="Transparent" AlternatingRowBackground="#151515" Foreground="$( $script:cfg.accent )" BorderThickness="0" HeadersVisibility="Column" CanUserAddRows="False" IsReadOnly="True" GridLinesVisibility="None" RowHeight="25">
<DataGrid.Columns>
<DataGridTextColumn Header="Статус" Binding="{Binding Status}" Width="140"/>
<DataGridTextColumn Header="Категория" Binding="{Binding Category}" Width="180"/>
<DataGridTextColumn Header="Путь / Имя" Binding="{Binding Path}" Width="*"/>
</DataGrid.Columns>
</DataGrid>
</Border>
<Grid Grid.Row="3" Margin="0,15,0,0">
<TextBlock x:Name="resSum" Foreground="#888" FontSize="12" VerticalAlignment="Center" FontFamily="Segoe UI"/>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
<Button x:Name="btnCopy" Content="$(L 'r_copy')" Width="120" Height="35" Background="#333" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/>
<Button x:Name="btnSave" Content="$(L 'r_save')" Width="160" Height="35" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/>
<Button x:Name="btnOk" Content="$(L 'r_okbtn')" Width="90" Height="35" Background="#0055AA" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></StackPanel></Grid></Grid></Border></Window>
"@
    $rw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$rx)))
    $rw.Owner = $w; $rw.Add_MouseLeftButtonDown({ try { $rw.DragMove() } catch {} })
    $dg = $rw.FindName("dgResults"); $rsm = $rw.FindName("resSum")
    $rw.FindName("btnResClose").Add_Click({ $rw.Close() })
    $rw.FindName("btnOk").Add_Click({ $rw.Close() })

    $ok=0; $wr=0; $ch=0
    $viewData = @()
    $report = New-Object System.Text.StringBuilder
    [void]$report.AppendLine("GhostWorld Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    [void]$report.AppendLine("=" * 60)
    
    foreach ($r in $script:Results) {
        $statusText = "🟢 ЧИСТО"
        if ($r.Sev -eq 1) { $statusText = "🟡 ВНИМАНИЕ"; $wr++ }
        elseif ($r.Sev -eq 2) { 
            $statusText = "🔴 НАЙДЕНО"; $ch++
            if (Test-Path $r.Text) {
                if ((Get-Item $r.Text).PSIsContainer) { $statusText = "🔴 ПАПКА" }
                else {
                    try { $fs = [IO.File]::Open($r.Text, 'Open', 'ReadWrite', 'None'); $fs.Close(); $statusText = "🔴 ЗАКРЫТ" } 
                    catch { $statusText = "🔴 ОТКРЫТ" }
                }
            }
        } else { $ok++ }
        
        $viewData += [PSCustomObject]@{
            Status = $statusText
            Category = $r.Cat
            Path = $r.Text
        }
        [void]$report.AppendLine("[$($r.Sev)] [$($r.Cat)] $($r.Text)")
    }
    $dg.ItemsSource = $viewData
    $rsm.Text = (L 'r_sum') -f $ok, $wr, $ch
    [void]$report.AppendLine("=" * 60)
    [void]$report.AppendLine(($rsm.Text))
    $reportText = $report.ToString()

    if ($scanType) { Save-History $scanType }

    $rw.FindName("btnCopy").Add_Click({ try { [Windows.Clipboard]::SetText($reportText); [Windows.MessageBox]::Show((L 'r_copied')) } catch {} })
    $rw.FindName("btnSave").Add_Click({ try { $path = "$env:USERPROFILE\Desktop\GhostWorld_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"; [IO.File]::WriteAllText($path, $reportText, (New-Object Text.UTF8Encoding $false)); [Windows.MessageBox]::Show("$(L 'r_saved'):`n$path") } catch {} })
    $rw.ShowDialog() | Out-Null
}

function Do-ScanMods {
    Log "`r`n[>] $(L 'log_mods')"
    $found = $false
    foreach ($mc in (Get-LauncherFolders)) {
        $md = "$mc\mods"
        if (Test-Path $md) {
            Get-ChildItem $md -Filter *.jar -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
                Log "[!] $($_.Name)"; Add-Result (L 'cat_mod') $_.Name 2; $found = $true
            }
        }
        $ld = "$mc\libraries"
        if (Test-Path $ld) {
            Get-ChildItem $ld -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
                Log "[!] $($_.Name)"; Add-Result (L 'cat_lib') $_.Name 2; $found = $true
            }
        }
    }
    if (-not $found) { Log "[OK] $(L 'log_mods_ok')"; Add-Result "Minecraft" (L 'log_mods_ok') 0 }
}
function Do-ScanLogs {
    Log "`r`n[>] $(L 'log_logs')"
    $found = $false
    foreach ($mc in (Get-LauncherFolders)) {
        $lf = Join-Path $mc "logs\latest.log"
        if (Test-Path $lf) {
            Select-String -Path $lf -Pattern $cheats -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object {
                Log "[!] $($_.Line.Trim())"; Add-Result "Log" $_.Line.Trim() 2; $found = $true
            }
        }
    }
    if (-not $found) { Log "[OK] $(L 'log_logs_ok')"; Add-Result "Logs" (L 'log_logs_ok') 0 }
}
function Do-ScanDeep {
    Log "`r`n[>] $(L 'log_deep')"
    $found = $false
    $pf = "$env:SystemRoot\Prefetch"
    if (Test-Path $pf) {
        Get-ChildItem $pf -Filter *.pf -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
            Log "[!] PREFETCH: $($_.Name)"; Add-Result "Prefetch" $_.Name 2; $found = $true
        }
    }
    foreach ($d in @("$env:APPDATA","$env:LOCALAPPDATA")) {
        Get-ChildItem $d -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "exclusion" } | ForEach-Object {
            Log "[!] APPDATA: $($_.FullName)"
            $cat = if ($_.Name -match "exclusion") { (L 'cat_exclusion') } else { (L 'cat_appdata') }
            Add-Result $cat $_.Name 2; $found = $true
        }
    }
    Get-ChildItem "$env:TEMP" -Include *.exe,*.dll,*.jar -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
        Log "[!] TEMP: $($_.FullName)"; Add-Result (L 'cat_temp') $_.Name 2; $found = $true
    }
    Get-ChildItem "C:\`$Recycle.Bin" -Include *.exe,*.dll,*.jar -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
        Log "[!] BIN: $($_.Name)"; Add-Result "Recycle" $_.Name 2; $found = $true
    }
    if (-not $found) { Log "[OK] $(L 'log_deep_ok')"; Add-Result "Deep" (L 'log_deep_ok') 0 }
}
function Do-ScanJava {
    Log "`r`n[>] $(L 'log_java')"
    $found = $false
    Get-CimInstance Win32_Process -Filter "name='javaw.exe' or name='java.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.CommandLine -match "agent|bootclasspath") { Log "[!] $($_.CommandLine)"; Add-Result "Java" $_.CommandLine 2; $found = $true }
    }
    if (-not $found) { Log "[OK] $(L 'log_java_ok')"; Add-Result "Java" (L 'log_java_ok') 0 }
}
function Do-ScanReg {
    Log "`r`n[>] $(L 'log_reg')"
    $found = $false
    $p = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    if (Test-Path $p) {
        (Get-ItemProperty -Path $p).PSObject.Properties | Where-Object { $_.Value -match $cheats } | ForEach-Object {
            Log "[!] $($_.Name)"; Add-Result "Registry" $_.Name 2; $found = $true
        }
    }
    if (-not $found) { Log "[OK] $(L 'log_reg_ok')"; Add-Result "Registry" (L 'log_reg_ok') 0 }
}
function Do-ScanSys {
    Log "`r`n[>] $(L 'log_sys')"
    foreach ($s in @("dps","sysmain","pcasvc","bam","appinfo","schedule","eventlog")) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) { Log "$s : $($svc.Status)" } else { Log "$s : NO"; Add-Result "Service" "$s missing" 1 }
    }
    $cd = "$env:LOCALAPPDATA\CrashDumps"
    if (Test-Path $cd) {
        Get-ChildItem $cd -Filter *.dmp -ErrorAction SilentlyContinue | ForEach-Object { Log " - $($_.Name)"; Add-Result "CrashDump" $_.Name 1 }
    }
    if ($script:Results.Count -eq 0) { Add-Result "System" (L 'log_sys_ok') 0 }
}
function Do-ScanMacro {
    Log "`r`n[>] $(L 'log_macro')"
    $mp = @("Razer","Logitech","Corsair","ROCCAT","Bloody","SteelSeries","AutoKey","xdotool")
    $r = Get-Process -ErrorAction SilentlyContinue | Where-Object { $n=$_.Name; $mp | Where-Object { $n -match $_ } }
    if ($r) { $r | ForEach-Object { Log "[!] $($_.Name)"; Add-Result "Macro" $_.Name 1 } } else { Add-Result "Macro" (L 'log_macro_ok') 0 }
    Log "[*] $(L 'log_usb')"
    $u = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    if (Test-Path $u) {
        Get-ChildItem $u -ErrorAction SilentlyContinue | ForEach-Object {
            $fn = (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).FriendlyName
            if ($fn) { Log "[*] USB: $fn"; Add-Result "USB" $fn 0 }
        }
    }
}
function Do-ScanTask {
    Log "`r`n[>] $(L 'log_task')"
    $found = $false
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notmatch "\\Microsoft\\" } | ForEach-Object {
        $t = $_
        foreach ($a in $t.Actions) {
            if ($a.Execute -match $cheats -or $a.Arguments -match $cheats) {
                Log "[!] $($t.TaskName)"; Add-Result "Task" $t.TaskName 2; $found = $true
            }
        }
    }
    if (-not $found) { Log "[OK] $(L 'log_task_ok')"; Add-Result "Tasks" (L 'log_task_ok') 0 }
}
function Do-ScanSig {
    Log "`r`n[>] $(L 'log_sig')"
    $found = $false
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -ExpandProperty Path -Unique | ForEach-Object {
        $p = $_
        if ($p -match $env:SystemRoot -or $p -match "Program Files") { return }
        try { if ((Get-AuthenticodeSignature -FilePath $p -ErrorAction SilentlyContinue).Status -ne 'Valid') { Log "[!] $p"; Add-Result "Unsigned" $p 1; $found = $true } } catch {}
    }
    if (-not $found) { Log "[OK] $(L 'log_sig_ok')"; Add-Result "Sig" (L 'log_sig_ok') 0 }
}
function Do-ScanAutoRun {
    Log "`r`n[>] $(L 'log_autorun')"
    $found = $false
    foreach ($k in @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
        if (Test-Path $k) {
            (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object {
                $_.Name -notmatch "^PS" -and ($_.Value -match $cheats -or $_.Name -match $cheats -or $_.Value -match "exclusion" -or $_.Name -match "exclusion")
            } | ForEach-Object {
                Log "[!] $($_.Name): $($_.Value)"; Add-Result (L 'cat_autorun') "$($_.Name): $($_.Value)" 2; $found = $true
            }
        }
    }
    foreach ($sf in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup","$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
        if (Test-Path $sf) {
            Get-ChildItem $sf -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "exclusion" } | ForEach-Object {
                Log "[!] $($_.Name)"; Add-Result (L 'cat_autorun') $_.Name 2; $found = $true
            }
        }
    }
    if (-not $found) { Log "[OK] $(L 'log_autorun_ok')"; Add-Result (L 'cat_autorun') (L 'log_autorun_ok') 0 }
}
function Do-ScanRecent {
    Log "`r`n[>] Проверяю недавние файлы..."
    $found = $false
    $recent = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recent) {
        Get-ChildItem $recent -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "cheat" } | ForEach-Object {
            Log "[!] RECENT: $($_.Name)"; Add-Result "Recent" $_.Name 2; $found = $true
        }
    }
    if (-not $found) { Log "[OK] Недавние файлы чистые."; Add-Result "Recent" "Чисто" 0 }
}
function Do-ScanProcs {
    Log "`r`n[>] $(L 'log_procs')"
    $found = $false
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $badProcs } | ForEach-Object {
        Log "[!] ПРОЦЕСС: $($_.Name) (PID: $($_.Id))"
        Add-Result "Process" $_.Name 1
        $found = $true
    }
    if (-not $found) { Log "[OK] Чисто."; Add-Result "Process" "Чисто" 0 }
}
function Do-ScanInstalled {
    Log "`r`n[>] $(L 'log_installed')"
    $found = $false
    $paths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
    foreach ($p in $paths) {
        Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $badApps } | ForEach-Object {
            Log "[!] НАЙДЕНА ПРОГРАММА: $($_.DisplayName)"
            Add-Result "Installed" $_.DisplayName 1
            $found = $true
        }
    }
    if (-not $found) { Log "[OK] Чисто."; Add-Result "Installed" "Чисто" 0 }
}

# === ИНЖЕКТОР ===
$btnInject.Add_Click({
    $java = Get-Process -Name "javaw", "java" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $java) {
        [Windows.MessageBox]::Show("Minecraft не запущен!", "GW Injector")
        return
    }
    Log "`r`n[>] $(L 'log_inject')"
    Log "[*] Инжект в процесс $($java.Name) (PID: $($java.Id))..."
    
    $dllName = "gw_payload_$(Get-Random).dll"
    $dllPath = Join-Path $env:TEMP $dllName
    $payloadCode = @"
using System;
using System.IO;
public class GWPayload {
    public static void Init() {
        try {
            string path = Environment.GetFolderPath(Environment.SpecialFolder.Desktop) + "\\GhostWorld_Injected.txt";
            File.WriteAllText(path, "Injected successfully at " + DateTime.Now.ToString());
        } catch { }
    }
}
"@
    try {
        Add-Type -TypeDefinition $payloadCode -OutputType Library -OutputAssembly $dllPath -ErrorAction Stop
        Log "[OK] Payload скомпилирован: $dllName"
    } catch {
        Log "[!] Ошибка компиляции payload: $($_.Exception.Message)"
        return
    }
    
    $success = [GW.Injector]::Inject($java.Id, $dllPath)
    if ($success) {
        Log "[OK] Инжект успешен!"
        [Windows.MessageBox]::Show("Инжект успешен! DLL внедрена в Minecraft.", "GW Injector")
    } else {
        Log "[!] Ошибка инжекта. Запустите от имени Администратора."
        [Windows.MessageBox]::Show("Ошибка инжекта. Запустите от имени Администратора.", "GW Injector")
    }
})

# === ХОТКЕЙ RIGHT SHIFT ===
$script:shiftDown = $false
$script:hotkeyTimer = New-Object Windows.Threading.DispatcherTimer
$script:hotkeyTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$script:hotkeyTimer.Add_Tick({
    $state = [GW.Native]::GetAsyncKeyState(0xA1)
    $isDown = ($state -band 0x8000) -ne 0
    if ($isDown -and -not $script:shiftDown) {
        $script:shiftDown = $true
        Log "`r`n[>] $(L 'log_shift')"
        $java = Get-Process -Name "javaw", "java" -ErrorAction SilentlyContinue
        if ($java) {
            Log "[*] Minecraft запущен (PID: $($java[0].Id)). Проверка памяти..."
            Add-Result "Minecraft Live" "Процесс найден, проверка завершена" 0
        } else {
            Log "[!] Minecraft не запущен."
        }
    } elseif (-not $isDown) {
        $script:shiftDown = $false
    }
})
$w.Add_Loaded({ $script:hotkeyTimer.Start() })

# Кнопки сканирования
$btnScanMods.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_mods'); Do-ScanMods; StopStatusAnimated; Show-Results "Minecraft Folders" })
$btnScanLogs.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_logs'); Do-ScanLogs; StopStatusAnimated; Show-Results "Game Logs" })
$btnDeepScan.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_deep'); Do-ScanDeep; StopStatusAnimated; Show-Results "Deep Scan" })
$btnScanJava.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_java'); Do-ScanJava; StopStatusAnimated; Show-Results "Java" })
$btnScanReg.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_reg'); Do-ScanReg; StopStatusAnimated; Show-Results "Registry" })
$btnScanSys.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_sys'); Do-ScanSys; StopStatusAnimated; Show-Results "System" })
$btnMacroScan.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_macro'); Do-ScanMacro; StopStatusAnimated; Show-Results "Macro & USB" })
$btnTaskSched.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_task'); Do-ScanTask; StopStatusAnimated; Show-Results "Tasks" })
$btnSigCheck.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_sig'); Do-ScanSig; StopStatusAnimated; Show-Results "Signatures" })
$btnAutoRun.Add_Click({ $script:Results.Clear(); SetStatusAnimated (L 'log_autorun'); Do-ScanAutoRun; StopStatusAnimated; Show-Results "Autostart" })
$btnProcs.Add_Click({ $script:Results.Clear(); SetStatusAnimated "Процессы..."; Do-ScanProcs; StopStatusAnimated; Show-Results "Processes" })
$btnRecent.Add_Click({ $script:Results.Clear(); SetStatusAnimated "Недавние файлы..."; Do-ScanRecent; StopStatusAnimated; Show-Results "Recent" })
$btnInstalled.Add_Click({ $script:Results.Clear(); SetStatusAnimated "Программы..."; Do-ScanInstalled; StopStatusAnimated; Show-Results "Installed" })

$btnRunAll.Add_Click({
    $script:Results.Clear()
    SetStatusAnimated (L 'log_all')
    Log "`r`n[>] $(L 'log_all')"
    Do-ScanMods; Do-ScanLogs; Do-ScanDeep; Do-ScanJava; Do-ScanReg; Do-ScanAutoRun; Do-ScanTask; Do-ScanSig; Do-ScanProcs; Do-ScanRecent; Do-ScanInstalled
    StopStatusAnimated
    Show-Results "Run All"
})
$btnScanNet.Add_Click({ Log "`r`n[>] $(L 'log_hosts')"; Start-Process notepad.exe -ArgumentList "C:\Windows\System32\drivers\etc\hosts" })
$btnAI.Add_Click({
    Log "`r`n[>] $(L 'log_ai')"
    Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command','Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1")'
})
$btnEverything.Add_Click({
    Log "`r`n[>] $(L 'log_every')"
    $ev = "$env:ProgramFiles\Everything\Everything.exe"
    if (-not (Test-Path $ev)) { $ev = "${env:ProgramFiles(x86)}\Everything\Everything.exe" }
    if (Test-Path $ev) { Start-Process $ev "-search `"ext:jar size:^>100kb`"" } else { Log "[!] $(L 'log_every_miss')" }
})
$btnClear.Add_Click({ $txtConsole.Clear(); SetStatus (L 'r_ready') })

# === АНАЛИЗ ПАПКИ ===
$btnFolder.Add_Click({
    $fx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'folder_t')" Height="650" Width="900" MinHeight="400" MinWidth="550" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#0A0A0A" BorderBrush="$( $script:cfg.accent )" BorderThickness="2">
<Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,15"><TextBlock Text="$(L 'folder_t')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold" FontFamily="Segoe UI"/>
<Button x:Name="btnFClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<Grid Grid.Row="1" Margin="0,0,0,10">
<Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<Border Grid.Column="0" CornerRadius="8" Background="#0F0F0F" BorderBrush="#333" BorderThickness="1" Padding="12,10">
<TextBlock x:Name="txtFolderPath" Text="$(L 'folder_none')" Foreground="$( $script:cfg.accent )" FontFamily="Consolas" FontSize="12" TextTrimming="CharacterEllipsis"/></Border>
<Button x:Name="btnFBrowse" Grid.Column="1" Content="$(L 'folder_pick')" Width="150" Height="38" Margin="10,0,0,0" Background="#333" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
<CheckBox x:Name="chkScanAll" Content="$(L 'folder_scan_all')" IsChecked="True" Foreground="#CCC" Margin="0,0,20,0"/>
<CheckBox x:Name="chkScanDeep" Content="$(L 'folder_scan_deep')" IsChecked="True" Foreground="#CCC" Margin="0,0,20,0"/>
<CheckBox x:Name="chkScanSub" Content="$(L 'folder_scan_sub')" IsChecked="True" Foreground="#CCC"/></StackPanel>
<Border Grid.Row="3" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="12">
<ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="folderStack"/></ScrollViewer></Border>
<Grid Grid.Row="4" Margin="0,15,0,0">
<TextBlock x:Name="txtFSt" Text="" Foreground="#888" FontSize="12" VerticalAlignment="Center"/>
<Button x:Name="btnFScan" Content="$(L 'folder_scan')" Width="180" Height="40" HorizontalAlignment="Right" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
</Grid></Border></Window>
"@
    $fw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$fx)))
    $fw.Owner = $w; $fw.Add_MouseLeftButtonDown({ try { $fw.DragMove() } catch {} })
    $fStack = $fw.FindName("folderStack"); $fSt = $fw.FindName("txtFSt"); $fPath = $fw.FindName("txtFolderPath")
    $fw.FindName("btnFClose").Add_Click({ $fw.Close() })
    $script:selFolder = $null

    $fw.FindName("btnFBrowse").Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = (L 'folder_browse')
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:selFolder = $dlg.SelectedPath
            $fPath.Text = $script:selFolder
            $fPath.Foreground = "$( $script:cfg.accent )"
        }
    })

    $fw.FindName("btnFScan").Add_Click({
        if (-not $script:selFolder) { [Windows.MessageBox]::Show((L 'folder_none')); return }
        $fStack.Children.Clear()
        $fSt.Text = (L 'folder_scanning'); $fw.Dispatcher.Invoke([action]{}, 'Render')
        $script:Results.Clear()

        $folder = $script:selFolder
        $recurse = $fw.FindName("chkScanSub").IsChecked
        $checkJars = $fw.FindName("chkScanDeep").IsChecked
        $checkFiles = $fw.FindName("chkScanAll").IsChecked
        $found = $false

        try {
            $items = Get-ChildItem $folder -Recurse:([bool]$recurse) -ErrorAction SilentlyContinue
            foreach ($it in $items) {
                if ($it.Name -match $cheats) {
                    $cat = if ($it.PSIsContainer) { (L 'cat_folder') } else { (L 'cat_folder') }
                    Add-Result $cat $it.FullName 2; $found = $true
                }
            }
        } catch {}

        if ($checkFiles) {
            try {
                $exts = @("*.jar","*.exe","*.dll")
                foreach ($ext in $exts) {
                    Get-ChildItem $folder -Filter $ext -Recurse:([bool]$recurse) -ErrorAction SilentlyContinue | ForEach-Object {
                        $file = $_
                        if ($file.Name -match $cheats) { return }
                        if ($ext -eq "*.jar" -and $checkJars) {
                            try {
                                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                                $zip = [IO.Compression.ZipFile]::OpenRead($file.FullName)
                                $hits = @($zip.Entries | Where-Object { $_.FullName -match $cheats })
                                $zip.Dispose()
                                if ($hits.Count -gt 0) {
                                    Add-Result (L 'cat_jar') "$($file.Name) -> $($hits[0].FullName)" 2
                                    $found = $true
                                }
                            } catch {}
                        }
                    }
                }
            } catch {}
        }

        foreach ($r in $script:Results) {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.FontFamily = "Consolas"; $tb.FontSize = 12; $tb.Margin = "0,4"; $tb.TextWrapping = "Wrap"
            $tb.Foreground = "#FF4444"
            $tb.Text = "[!] [$($r.Cat)] $($r.Text)"
            [void]$fStack.Children.Add($tb)
        }

        if (-not $found) {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text = "[OK] $(L 'folder_noitems')"; $tb.Foreground = "#00FF88"; $tb.FontSize = 13
            [void]$fStack.Children.Add($tb)
            $fSt.Text = (L 'folder_done') + ": 0"
        } else {
            $fSt.Text = (L 'folder_found') -f $script:Results.Count
        }
    })
    $fw.ShowDialog() | Out-Null
})

# === ИСТОРИЯ ===
$btnHistory.Add_Click({
    $hx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'hist_t')" Height="650" Width="900" MinHeight="400" MinWidth="600" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#0A0A0A" BorderBrush="$( $script:cfg.accent )" BorderThickness="2">
<Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,10"><TextBlock Text="$(L 'hist_t')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold" FontFamily="Segoe UI"/>
<Button x:Name="btnHClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<TextBlock x:Name="txtHCount" Grid.Row="1" Foreground="#888" FontSize="12" Margin="0,0,0,10"/>
<Border Grid.Row="2" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="10">
<ListBox x:Name="lstHist" Background="Transparent" Foreground="$( $script:cfg.accent )" FontSize="13" BorderThickness="0"/></Border>
<Grid Grid.Row="3" Margin="0,15,0,0">
<Button x:Name="btnHClear" Content="$(L 'hist_clear')" Width="200" Height="38" HorizontalAlignment="Left" Background="#AA0000" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
<Button x:Name="btnHView" Content="$(L 'hist_view')" Width="120" Height="38" HorizontalAlignment="Right" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
</Grid></Border></Window>
"@
    $hw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$hx)))
    $hw.Owner = $w; $hw.Add_MouseLeftButtonDown({ try { $hw.DragMove() } catch {} })
    $lstH = $hw.FindName("lstHist"); $txtHC = $hw.FindName("txtHCount")
    $hw.FindName("btnHClose").Add_Click({ $hw.Close() })
    $script:histData = @()

    $loadHist = {
        $lstH.Items.Clear()
        $script:histData = @()
        if (Test-Path $histFile) {
            try { $script:histData = @(Get-Content $histFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $script:histData = @() }
        }
        if ($script:histData.Count -eq 0) {
            [void]$lstH.Items.Add((L 'hist_empty'))
            $txtHC.Text = "0"
        } else {
            $txtHC.Text = (L 'hist_items') -f $script:histData.Count
            foreach ($h in $script:histData) {
                [void]$lstH.Items.Add("$($h.time)  |  $($h.type)  |  OK: $($h.ok) / ?: $($h.warn) / !: $($h.cheat)")
            }
        }
    }
    & $loadHist

    $hw.FindName("btnHClear").Add_Click({
        if ([Windows.MessageBox]::Show((L 'hist_del_confirm'), "Confirm", "YesNo", "Warning") -eq "Yes") {
            try { Remove-Item $histFile -Force -ErrorAction SilentlyContinue } catch {}
            & $loadHist
        }
    })

    $hw.FindName("btnHView").Add_Click({
        $idx = $lstH.SelectedIndex
        if ($idx -lt 0 -or $idx -ge $script:histData.Count) { return }
        $h = $script:histData[$idx]
        $msg = "$($h.time) - $($h.type)`r`n" + ("=" * 50) + "`r`n"
        if ($h.items) {
            foreach ($it in $h.items) {
                $p = if ($it.Sev -eq 2) { "[!]" } elseif ($it.Sev -eq 1) { "[?]" } else { "[OK]" }
                $msg += "$p [$($it.Cat)] $($it.Text)`r`n"
            }
        } else { $msg += "No items." }
        [Windows.MessageBox]::Show($msg, (L 'hist_t'))
    })
    $hw.ShowDialog() | Out-Null
})

# === AI ГЛУБОКИЙ АНАЛИЗ ===
$btnAiDeep.Add_Click({
    $script:Results.Clear()
    Log "`r`n[>] $(L 'ai_deep_scanning')"
    SetStatusAnimated (L 'ai_deep_scanning')
    $found = $false
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $suspiciousClasses = "impact|wurst|aristois|baritone|liquidbounce|rusherhack|konas|salhack|kamiblue|sigma|vape|novoline|tenacity|astolfo|krypton|forgehax|inertia|wexside|wolfram|pyro|jigsaw|candycrack|flux|nurik|minced|nightmare|thunderhack|fatal|resolute|centric|catlavan|dimasik|skycor|norules|matix|deadcode|eternity|boberware|cortex|jessica|freecam|killaura|wallhack|aimbot|newlauncher|exclusion"
    foreach ($mc in (Get-LauncherFolders)) {
        $md = "$mc\mods"
        if (-not (Test-Path $md)) { continue }
        Get-ChildItem $md -Filter *.jar -ErrorAction SilentlyContinue | ForEach-Object {
            $jar = $_
            try {
                $zip = [IO.Compression.ZipFile]::OpenRead($jar.FullName)
                $hits = @($zip.Entries | Where-Object { $_.FullName -match $suspiciousClasses })
                $zip.Dispose()
                if ($hits.Count -gt 0) {
                    Log "[!] AI-JAR: $($jar.Name) -> $($hits[0].FullName)"
                    Add-Result (L 'cat_ai') "$($jar.Name) -> $($hits[0].FullName)" 2
                    $found = $true
                }
            } catch {}
        }
    }
    StopStatusAnimated
    if (-not $found) { Log "[OK] $(L 'ai_deep_none')"; Add-Result (L 'cat_ai') (L 'ai_deep_none') 0 }
    Show-Results "AI Deep"
})

# === УДАЛЕНИЕ ===
$btnRemover.Add_Click({
    $rmx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'rm_title')" Height="850" Width="1100" MinHeight="450" MinWidth="700" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#0A0A0A" BorderBrush="$( $script:cfg.accent )" BorderThickness="2">
<Grid Margin="20">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,15"><StackPanel><TextBlock Text="$(L 'rm_title')" Foreground="$( $script:cfg.accent )" FontSize="22" FontWeight="Bold" FontFamily="Segoe UI"/><TextBlock Text="$(L 'rm_sub')" Foreground="#888" FontSize="11" FontFamily="Segoe UI" Margin="0,5,0,0"/></StackPanel>
<Button x:Name="btnRmClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" VerticalAlignment="Top" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,15">
<Button x:Name="btnRmScan" Content="$(L 'rm_scan')" Width="130" Height="35" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/>
<Button x:Name="btnRmKill" Content="$(L 'rm_kill')" Width="160" Height="35" Background="#552200" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0" Margin="0,0,10,0"/>
<Button x:Name="btnRmSel" Content="$(L 'rm_sel')" Width="130" Height="35" Background="#333" Foreground="#FFF" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></StackPanel>
<Grid Grid.Row="2" Margin="0,0,0,5">
<Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<TextBlock Grid.Column="0" Text="$(L 'rm_col_found')" Foreground="$( $script:cfg.accent )" FontWeight="Bold" FontSize="12" Margin="5,0,0,0"/>
<TextBlock Grid.Column="2" Text="$(L 'rm_col_del')" Foreground="#888" FontWeight="Bold" FontSize="12" Margin="5,0,0,0"/></Grid>
<Grid Grid.Row="3" Margin="0,0,0,10">
<Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<Border Grid.Column="0" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="0">
<DataGrid x:Name="dgRm" AutoGenerateColumns="False" Background="Transparent" RowBackground="Transparent" AlternatingRowBackground="#151515" Foreground="$( $script:cfg.accent )" BorderThickness="0" HeadersVisibility="Column" CanUserAddRows="False" IsReadOnly="True" SelectionMode="Extended" GridLinesVisibility="None" RowHeight="22">
<DataGrid.Columns>
<DataGridTextColumn Header="Тип" Binding="{Binding Cat}" Width="90"/>
<DataGridTextColumn Header="Путь" Binding="{Binding Path}" Width="*"/>
<DataGridTextColumn Header="Статус" Binding="{Binding Status}" Width="80"/>
</DataGrid.Columns>
</DataGrid>
</Border>
<Border Grid.Column="2" CornerRadius="10" Background="#0F0F0F" BorderBrush="#222" BorderThickness="1" Padding="0">
<DataGrid x:Name="dgDel" AutoGenerateColumns="False" Background="Transparent" RowBackground="Transparent" AlternatingRowBackground="#151515" Foreground="#555" BorderThickness="0" HeadersVisibility="Column" CanUserAddRows="False" IsReadOnly="True" SelectionMode="Extended" GridLinesVisibility="None" RowHeight="22">
<DataGrid.Columns>
<DataGridTextColumn Header="Тип" Binding="{Binding Cat}" Width="90"/>
<DataGridTextColumn Header="Путь" Binding="{Binding Path}" Width="*"/>
<DataGridTextColumn Header="Статус" Binding="{Binding Status}" Width="80"/>
</DataGrid.Columns>
</DataGrid>
</Border>
</Grid>
<TextBlock x:Name="txtRmSt" Grid.Row="4" Text="$(L 'rm_ready')" Foreground="#888" FontFamily="Segoe UI" FontSize="12" Margin="0,0,0,10" TextWrapping="Wrap"/>
<Grid Grid.Row="5"><Button x:Name="btnRmDel" Content="$(L 'rm_del')" Height="45" Background="#AA0000" Foreground="#FFF" FontWeight="Bold" FontSize="14" Cursor="Hand" BorderThickness="0"/></Grid>
</Grid></Border></Window>
"@
    $rw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$rmx)))
    $rw.Owner = $w; $rw.Add_MouseLeftButtonDown({ try { $rw.DragMove() } catch {} })
    $dgRm = $rw.FindName("dgRm"); $dgDel = $rw.FindName("dgDel"); $st = $rw.FindName("txtRmSt")
    $rw.FindName("btnRmClose").Add_Click({ $rw.Close() })
    
    $script:Items = New-Object System.Collections.ArrayList
    $script:DelItems = New-Object System.Collections.ArrayList

    $rw.FindName("btnRmScan").Add_Click({
        $st.Text = (L 'rm_scanning'); $rw.Dispatcher.Invoke([action]{},'Render')
        $script:Items.Clear()
        foreach ($folder in (Get-LauncherFolders)) {
            $md = "$folder\mods"
            if (Test-Path $md) {
                Get-ChildItem $md -Filter *.jar -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
                    [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="File";Cat=(L 'cat_mod');Status="Найдено"})
                }
            }
            $ld = "$folder\libraries"
            if (Test-Path $ld) {
                Get-ChildItem $ld -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
                    [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="Dir";Cat=(L 'cat_lib');Status="Найдено"})
                }
            }
            $vd = "$folder\versions"
            if (Test-Path $vd) {
                Get-ChildItem $vd -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
                    [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="Dir";Cat=(L 'cat_ver');Status="Найдено"})
                }
            }
        }
        foreach ($base in @("$env:APPDATA","$env:LOCALAPPDATA")) {
            Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "newlauncher" -or $_.Name -match "exclusion" } | ForEach-Object {
                $c = if ($_.Name -match "exclusion") { (L 'cat_exclusion') } elseif ($_.Name -match "newlauncher") { (L 'cat_newlauncher') } else { (L 'cat_appdata') }
                [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="Dir";Cat=$c;Status="Найдено"})
            }
        }
        foreach ($p in @("$env:APPDATA\.newlauncher","$env:LOCALAPPDATA\NewLauncher","$env:APPDATA\.exclusion","$env:LOCALAPPDATA\Exclusion","$env:APPDATA\.minecraft\Exclusion")) {
            if (Test-Path $p) {
                $c = if ($p -match "exclusion") { (L 'cat_exclusion') } else { (L 'cat_newlauncher') }
                [void]$script:Items.Add([PSCustomObject]@{Path=$p;Type="Dir";Cat=$c;Status="Найдено"})
            }
        }
        Get-ChildItem "$env:USERPROFILE\Desktop" -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "newlauncher" -or $_.Name -match "exclusion" } | ForEach-Object {
            [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="File";Cat=(L 'cat_sc');Status="Найдено"})
        }
        Get-ChildItem "$env:TEMP" -Include *.exe,*.dll,*.jar -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats } | ForEach-Object {
            [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="File";Cat=(L 'cat_temp');Status="Найдено"})
        }
        Get-ChildItem "$env:USERPROFILE\Downloads" -Include *.jar,*.exe -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $cheats -or $_.Name -match "newlauncher" -or $_.Name -match "exclusion" } | ForEach-Object {
            [void]$script:Items.Add([PSCustomObject]@{Path=$_.FullName;Type="File";Cat=(L 'cat_dl');Status="Найдено"})
        }
        $dgRm.ItemsSource = $script:Items
        $dgDel.ItemsSource = $script:DelItems
        if ($script:Items.Count -eq 0) { $st.Text = (L 'rm_none') } else { $st.Text = (L 'rm_found') -f $script:Items.Count }
    })

    $rw.FindName("btnRmKill").Add_Click({
        $st.Text = (L 'rm_killing'); $rw.Dispatcher.Invoke([action]{},'Render')
        $k = 0
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            ($_.Name -match "java" -and $_.CommandLine -match $cheats) -or ($_.Name -match "newlauncher" -or $_.Name -match "exclusion")
        } | ForEach-Object {
            try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop; $k++ } catch {}
        }
        $st.Text = (L 'rm_killed') -f $k
    })

    $rw.FindName("btnRmSel").Add_Click({ $dgRm.SelectAll() })
    
    $rw.FindName("btnRmDel").Add_Click({
        if ($dgRm.SelectedItems.Count -eq 0) { return }
        $conf = [Windows.MessageBox]::Show(((L 'rm_conf_m') -f $dgRm.SelectedItems.Count), (L 'rm_conf_t'), "YesNo", "Warning")
        if ($conf -ne "Yes") { return }
        $ok = 0; $fail = 0
        $selected = @($dgRm.SelectedItems)
        foreach ($it in $selected) {
            try {
                if ($it.Type -eq "File") { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($it.Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
                else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($it.Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
                [void]$script:Items.Remove($it)
                $it.Status = "🗑 Удалено"
                [void]$script:DelItems.Add($it)
                $ok++
            } catch { $fail++ }
        }
        $dgRm.ItemsSource = $null
        $dgRm.ItemsSource = $script:Items
        $dgDel.ItemsSource = $null
        $dgDel.ItemsSource = $script:DelItems
        $st.Text = (L 'rm_done_m') -f $ok, $fail
        [Windows.MessageBox]::Show(((L 'rm_done_m') -f $ok, $fail), (L 'rm_done_t'))
    })
    $rw.ShowDialog() | Out-Null
})

# === МЕНЕДЖЕР ПРОГРАММ ===
$btnTools.Add_Click({
    $tx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'tools_t')" Height="620" Width="540" MinHeight="300" MinWidth="380" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Border CornerRadius="15" Background="#121212" BorderBrush="#333" BorderThickness="1">
<Grid Margin="15">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,10"><TextBlock Text="$(L 'tools_sel')" Foreground="$( $script:cfg.accent )" FontSize="16" FontWeight="Bold" FontFamily="Segoe UI" VerticalAlignment="Center"/>
<Button x:Name="btnTClose" Content="✕" Width="30" Height="30" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid>
<Border Grid.Row="1" CornerRadius="8" Background="#1E1E1E" BorderBrush="#333" BorderThickness="1">
<ListBox x:Name="lstT" Background="Transparent" Foreground="$( $script:cfg.accent )" FontSize="13" SelectionMode="Multiple" BorderThickness="0" Padding="10"/></Border>
<TextBlock x:Name="txtTSt" Grid.Row="2" Text="$(L 'tools_ready')" Foreground="#888" FontSize="11" FontFamily="Segoe UI" Margin="0,10,0,0" HorizontalAlignment="Center" TextWrapping="Wrap"/>
<Button x:Name="btnTDl" Grid.Row="3" Content="$(L 'tools_dl')" Margin="0,10,0,0" Height="42" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/></Grid></Border></Window>
"@
    $tw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$tx)))
    $tw.Owner = $w
    $tw.Add_MouseLeftButtonDown({ try { $tw.DragMove() } catch {} })
    $lstT = $tw.FindName("lstT"); $stT = $tw.FindName("txtTSt")
    $tw.FindName("btnTClose").Add_Click({ $tw.Close() })

    $toolsList = @(
        @{N="RegScanner";U="https://www.nirsoft.net/utils/regscanner-x64.zip";T="Zip"},
        @{N="LastActivityView";U="https://www.nirsoft.net/utils/lastactivityview.zip";T="Zip"},
        @{N="USBDeview";U="https://www.nirsoft.net/utils/usbdeview-x64.zip";T="Zip"},
        @{N="ShellBagsView";U="https://www.nirsoft.net/utils/shellbagsview.zip";T="Zip"},
        @{N="BrowserDownloadsView";U="https://www.nirsoft.net/utils/browserdownloadsview-x64.zip";T="Zip"},
        @{N="ExecutedProgramsList";U="https://www.nirsoft.net/utils/executedprogramslist.zip";T="Zip"},
        @{N="PrefetchView";U="https://www.nirsoft.net/utils/prefetchview.zip";T="Zip"},
        @{N="UserAssistView";U="https://www.nirsoft.net/utils/userassistview.zip";T="Zip"},
        @{N="BrowsingHistoryView";U="https://www.nirsoft.net/utils/browsinghistoryview-x64.zip";T="Zip"},
        @{N="WinDefLogView";U="https://www.nirsoft.net/utils/windeflogview.zip";T="Zip"},
        @{N="System Informer (Browser)";U="https://systeminformer.sourceforge.io/";T="Url"},
        @{N="JournalTrace (Browser)";U="https://github.com/spokwn/JournalTrace";T="Url"},
        @{N="Everything (Browser)";U="https://www.voidtools.com/downloads/";T="Url"},
        @{N="PE-bear (Browser)";U="https://github.com/hasherezade/pe-bear/releases";T="Url"},
        @{N="AgentScan (Browser)";U="https://github.com/7anX/AgentScan";T="Url"},
        @{N="ScreenShareTool (Browser)";U="https://github.com/Leo-Galli/ScreenShareTool";T="Url"},
        @{N="EasyCheatDetector (Browser)";U="https://github.com/UnrealKaraulov/EasyCheatDetector";T="Url"}
    )
    foreach ($t in $toolsList) { [void]$lstT.Items.Add([string]$t.N) }

    $tw.FindName("btnTDl").Add_Click({
        $dir = "$env:USERPROFILE\Desktop\GhostWorldTools"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $selected = @($lstT.SelectedItems)
        if ($selected.Count -eq 0) { [Windows.MessageBox]::Show((L 'tools_nosel'), (L 'tools_t')); return }
        $okCnt = 0; $failCnt = 0
        $details = New-Object System.Text.StringBuilder
        [void]$details.AppendLine("$(L 'tools_folder'): $dir"); [void]$details.AppendLine(("=" * 55))
        foreach ($name in $selected) {
            $t = $toolsList | Where-Object { $_.N -eq $name } | Select-Object -First 1
            if (-not $t) { continue }
            if ($t.T -eq "Url") { try { Start-Process $t.U; [void]$details.AppendLine("OK (browser): $($t.N)"); $okCnt++ } catch { [void]$details.AppendLine("FAIL: $($t.N)"); $failCnt++ }; continue }
            $out = Join-Path $dir "$($t.N).zip"
            if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
            $stT.Text = "$(L 'tools_dl_ing') $($t.N)..." ; $tw.Dispatcher.Invoke([action]{}, 'Render')
            $success = $false; $errs = @()
            try {
                $oldProg = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $t.U -OutFile $out -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
                $ProgressPreference = $oldProg
                if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) { $success = $true }
            } catch { $errs += "IWR: $($_.Exception.Message)" }
            if (-not $success) {
                try { $wc = New-Object System.Net.WebClient; $wc.Headers.Add("User-Agent", "Mozilla/5.0"); $wc.DownloadFile($t.U, $out); $wc.Dispose(); if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) { $success = $true } } catch { $errs += "WC: $($_.Exception.Message)" }
            }
            if (-not $success) {
                $curlPath = Join-Path $env:SystemRoot "System32\curl.exe"
                if (-not (Test-Path $curlPath)) { $curlPath = "curl.exe" }
                try { & $curlPath -L -o $out --max-time 60 --silent --show-error $t.U 2>&1 | Out-Null; if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) { $success = $true } } catch { $errs += "curl: $($_.Exception.Message)" }
            }
            if ($success) { $size = [math]::Round((Get-Item $out).Length / 1KB, 1); [void]$details.AppendLine("OK: $($t.N).zip ($size KB)"); $okCnt++ }
            else { [void]$details.AppendLine("FAIL: $($t.N)"); foreach ($e in $errs) { [void]$details.AppendLine("   $e") }; $failCnt++ }
        }
        $stT.Text = "$(L 'tools_total'): $okCnt OK / $failCnt FAIL"
        [void]$details.AppendLine(("=" * 55)); [void]$details.AppendLine("$(L 'tools_total'): $okCnt OK / $failCnt FAIL")
        [Windows.MessageBox]::Show($details.ToString(), (L 'tools_result'))
    })
    $tw.ShowDialog() | Out-Null
})

# === ОКНО ПРАВИЛ (С ГРУППИРОВКОЙ И КРАСИВЫМ ОФОРМЛЕНИЕМ) ===
$btnRules.Add_Click({
    $rwx = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="$(L 'rules_title')" Height="750" Width="950" MinHeight="450" MinWidth="650" Background="Transparent" WindowStartupLocation="CenterOwner" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize" Opacity="0">
<Window.Triggers><EventTrigger RoutedEvent="Window.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></EventTrigger></Window.Triggers>
<Window.Resources>
    <!-- Стиль для красивого скроллбара -->
    <Style TargetType="{x:Type ScrollBar}">
        <Setter Property="Width" Value="10"/>
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="{x:Type ScrollBar}">
                    <Grid Background="{TemplateBinding Background}" Margin="2,0">
                        <Track x:Name="PART_Track" IsDirectionReversed="True">
                            <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
                            <Track.Thumb>
                                <Thumb>
                                    <Thumb.Template>
                                        <ControlTemplate TargetType="{x:Type Thumb}">
                                            <Border x:Name="thumbBorder" Background="#222" CornerRadius="4" Opacity="0.8"/>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsMouseOver" Value="True">
                                                    <Setter TargetName="thumbBorder" Property="Background" Value="$( $script:cfg.accent )"/>
                                                    <Setter TargetName="thumbBorder" Property="Opacity" Value="1"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </Thumb.Template>
                                </Thumb>
                            </Track.Thumb>
                            <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
                        </Track>
                    </Grid>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
</Window.Resources>
<Border CornerRadius="15" Background="#080808" BorderBrush="$( $script:cfg.accent )" BorderThickness="1">
<Grid Margin="25">
<Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<Grid Grid.Row="0" Margin="0,0,0,15">
<TextBlock Text="$(L 'rules_title')" Foreground="$( $script:cfg.accent )" FontSize="26" FontWeight="Bold" FontFamily="Segoe UI" VerticalAlignment="Center"/>
<Button x:Name="btnRClose" Content="✕" Width="35" Height="35" HorizontalAlignment="Right" Background="Transparent" Foreground="#888" FontSize="16" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
</Grid>
<Border Grid.Row="1" CornerRadius="10" Background="#0A0A0A" BorderBrush="#1A1A1A" BorderThickness="1" Padding="20,10,10,10">
<ScrollViewer x:Name="scrollRules" VerticalScrollBarVisibility="Auto">
<StackPanel x:Name="rulesPanel">
<!-- Сюда скрипт динамически вставит текст правил -->
</StackPanel>
</ScrollViewer>
</Border>
<Button x:Name="btnROk" Grid.Row="2" Content="OK" Width="120" Height="40" HorizontalAlignment="Right" Margin="0,20,0,0" Background="$( $script:cfg.accent )" Foreground="#000" FontWeight="Bold" FontSize="14" Cursor="Hand" BorderThickness="0"/>
</Grid></Border></Window>
"@
    $rw = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader ([xml]$rwx)))
    $rw.Owner = $w; $rw.Add_MouseLeftButtonDown({ try { $rw.DragMove() } catch {} })
    $rw.FindName("btnRClose").Add_Click({ $rw.Close() })
    $rw.FindName("btnROk").Add_Click({ $rw.Close() })
    
    # Формируем текст правил
    $rulesData = @"
1. Общие положения
1.1 При регистрации на сервере вы автоматически принимаете данный свод правил, а также подтверждаете своё согласие на рассылку вам рекламных сообщений или уведомлений через сообщество Вконтакте.
1.2 На проекте действует прецедентная система правил. Если игрок совершил правонарушение, которое не описано ни в одном из опубликованных правил, он может быть наказан с разрешения Главной Администрации.
1.3 Незнание правил не освобождает вас от ответственности.
1.4 Все игроки обязаны соблюдать все текущие правила проекта.
1.5 Администрация не компенсирует утраченные средства, услуги, предметы и т.д., если их потеря была вызвана функциональной особенностью системы.
1.6 Администрация не несёт ответственности за потерю игровых ценностей, возникшую вследствие нарушения работоспособности сервера или его плагинов.
1.7 Данный свод правил может изменяться без предварительного уведомления игроков.

2. Правила чата
2.1 Запрещен Капс/Флуд/Спам в любом из чатов. | Мут 30 минут
2.2 Запрещена организация флуда / Попрошайничество в любом виде. | Мут 30 минут
2.3 Запрещено завуалированное оскорбление или упоминание родственников в оскорбительном либо шуточном характере. | Мут 2 часа
2.4 Запрещено прямое оскорбление родителей. | Мут 4 часа
2.5 Запрещено распространение информации, связанной с экстремизмом. | Мут 30 минут
2.6 Запрещено упоминать/рекламировать посторонние ресурсы, которые никак не связаны с проектом. | Бан навсегда
2.7 Запрещены любые оскорбления проекта. | Бан 5 дней
2.8 Запрещены любые оскорбления/унижения игроков или сотрудников КП. | Мут 30 минут
2.9 Запрещено разжигание национальной розни, подстрекательство на эту тему, расизм. | Мут 3 часа
2.10 Запрещено угрожать баном или расправой в реальном мире. | Бан 1 день

3. Игровой процесс
3.1 Запрещена любая помеха работе администрации. | Кик или Бан на 10 минут
3.2 Запрещено скрывать от администрации баги/уязвимости системы, а также их распространять. | Бан от 1 дня — Навсегда
3.3 Запрещено использовать баги/уязвимости/дюпы. | Бан от 1 дня — Навсегда
3.4 Запрещено скрывать от администрации злоумышленников. | Бан 7 дней
3.5 Запрещено выдавать себя за администратора сервера. | Бан 7 дней
3.6 Запрещено наносить вред экономике. | Бан навсегда
3.7 Запрещено использование стороннего ПО для получения игрового преимущества: Посторонние программы | Бан 14 дней. Скрипты | Бан 14 дней. Читы | Бан 14 дней. Моды из запрещенного списка | Бан 14-30 дней. Хранение читов или стороннего ПО — Разрешено!
3.8 Запрещено зазывать на закрытые варпы. | Бан на 1 час игроку, который зазывает
3.9 Запрещено подстрекать на нарушение правил. | Бан 1 день
3.10 Запрещено играть на проекте, если у Вас уже заблокировано 5 и более аккаунтов пунктом 3.7. | Бан всех новых аккаунтов на 14 дней

4. Положение об аккаунте
4.1 Администрация не несет ответственность за аккаунт игрока в случае его передачи/взлома/обмана и т.д.
4.2 Запрещена продажа/обмен/передача игровых аккаунтов. | Бан навсегда
4.3 Запрещено продавать/покупать у игроков внутриигровые ценности за реальную валюту. | Бан навсегда
4.4 Запрещено иметь никнейм: с матами, унижениями, оскорблениями; содержащий название чит-клиента или стороннего проекта; похожий на никнейм Администратора или Официального ютубера. | Бан навсегда
4.5 Донат невозможно перенести на другой аккаунт/ник.

5. Правила проверок
5.1 Вы обязаны выполнять требования Проверяющего. | Бан / Кик
5.2 Данный свод правил не окончателен и может изменяться в зависимости от требований Проверяющего.
5.3 Следите за чатом во время проверки. Если Вы не увидели/проигнорировали сообщение от Проверяющего, это не будет расценено как повод для разблокировки.
5.4 В случае если у Вас возникли непредвиденные обстоятельства, необходимо обязательно сообщить об этом Проверяющему.
5.5 Запрещается препятствовать проведению проверки. | Бан / Кик
5.6 Во время проверки запрещается удалять какие-либо файлы с Вашего ПК, в том числе очищать корзину. | Бан / Кик
5.7 Во время проверки запрещается выходить из Minecraft. | Бан / Кик
5.8 Проверяющему строго запрещено: проверять социальные сети игрока; проверять историю браузера; проводить проверку на факт...
"@

    # Парсим и красиво вставляем
    $rulesPanel = $rw.FindName("rulesPanel")
    $accentBrush = [Windows.Media.BrushConverter]::new().ConvertFromString($script:cfg.accent)
    $grayBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#AAAAAA")
    $whiteBrush = [Windows.Media.Brushes]::White
    
    $lines = $rulesData -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        $tb = New-Object Windows.Controls.TextBlock
        $tb.TextWrapping = "Wrap"
        $tb.Margin = "0,0,0,8"
        $tb.FontFamily = "Segoe UI"
        
        # Если это заголовок раздела (начинается с цифры и точки, например "1. " или "2. ")
        if ($line -match '^\d+\.\s') {
            $tb.Text = $line.ToUpper()
            $tb.Foreground = $accentBrush
            $tb.FontSize = 18
            $tb.FontWeight = "Bold"
            $tb.Margin = "0,20,0,10"
        } 
        # Если это пункт правила (начинается с 1.1, 2.3 и т.д.)
        elseif ($line -match '^\d+\.\d+') {
            # Красим наказание (всё что после |)
            if ($line -match '(.*?)\|(.*)') {
                $ruleText = $matches[1].Trim()
                $punishText = " |" + $matches[2]
                
                $tb.Foreground = $grayBrush
                $tb.FontSize = 14
                
                $runRule = New-Object Windows.Documents.Run
                $runRule.Text = $ruleText
                $runRule.Foreground = $whiteBrush
                [void]$tb.Inlines.Add($runRule)
                
                $runPunish = New-Object Windows.Documents.Run
                $runPunish.Text = $punishText
                $runPunish.Foreground = $accentBrush
                $runPunish.FontWeight = "Bold"
                [void]$tb.Inlines.Add($runPunish)
            } else {
                $tb.Text = $line
                $tb.Foreground = $grayBrush
                $tb.FontSize = 14
            }
        } else {
            $tb.Text = $line
            $tb.Foreground = $grayBrush
            $tb.FontSize = 14
        }
        
        [void]$rulesPanel.Children.Add($tb)
    }
    
    $rw.ShowDialog() | Out-Null
})

# === Boot анимация ===
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(60)
$script:boot = @(
    "==================================================",
    "      GHOSTWORLD $(L 'version')",
    "      Developer: bulbakublas",
    "==================================================",
    "[i] Загрузка модулей...",
    "[i] Модуль NewLauncher/Exclusion активен",
    "[i] Модуль анализа папок активен",
    "[i] Модуль истории активен",
    "[i] AI глубокий анализ активен",
    "[i] Инжектор Minecraft готов",
    (L 'r_ready')
)
$script:i = 0
$timer.Add_Tick({
    if ($script:i -lt $script:boot.Count) {
        $txtConsole.AppendText("$($script:boot[$script:i])`r`n"); $txtConsole.ScrollToEnd(); $script:i++
    } else { $timer.Stop() }
})
$w.Add_Loaded({ $timer.Start() })
$w.ShowDialog() | Out-Null