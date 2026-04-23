package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"charm.land/bubbles/v2/filepicker"
	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/table"
	"charm.land/bubbles/v2/textarea"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/glamour/v2"
	"charm.land/lipgloss/v2"
)

type pane int

const (
	paneWorkflows pane = iota
	paneDevices
	paneDetails
	paneNotes
)

type workflowItem struct {
	title    string
	desc     string
	markdown string
}

func (w workflowItem) Title() string       { return w.title }
func (w workflowItem) Description() string { return w.desc }
func (w workflowItem) FilterValue() string { return w.title + " " + w.desc }

type keyMap struct {
	FocusNext key.Binding
	FocusPrev key.Binding
	Run       key.Binding
	PickAPK   key.Binding
	SaveNote  key.Binding
	Refresh   key.Binding
	Help      key.Binding
	Quit      key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.FocusNext, k.Run, k.PickAPK, k.SaveNote, k.Help, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.FocusNext, k.FocusPrev, k.Run, k.Refresh},
		{k.PickAPK, k.SaveNote, k.Help, k.Quit},
	}
}

type actionCompleteMsg struct {
	workflow string
	device   string
	apk      string
	logLine  string
}

type savedNoteMsg struct {
	path string
	err  error
}

type uiStyles struct {
	app         lipgloss.Style
	header      lipgloss.Style
	headerRight lipgloss.Style
	focusedPane lipgloss.Style
	pane        lipgloss.Style
	footer      lipgloss.Style
	modal       lipgloss.Style
	statusOK    lipgloss.Style
	statusBusy  lipgloss.Style
	statusWarn  lipgloss.Style
}

type model struct {
	width  int
	height int
	ready  bool
	dark   bool

	focus      pane
	showPicker bool
	running    bool
	status     string

	notesPath   string
	selectedAPK string
	logs        []string

	keys   keyMap
	help   help.Model
	styles uiStyles

	workflowList list.Model
	devicesTable table.Model
	details      viewport.Model
	notes        textarea.Model
	picker       filepicker.Model
	spinner      spinner.Model

	detailsWidth  int
	detailsHeight int
}

func defaultKeyMap() keyMap {
	return keyMap{
		FocusNext: key.NewBinding(
			key.WithKeys("tab"),
			key.WithHelp("tab", "next pane"),
		),
		FocusPrev: key.NewBinding(
			key.WithKeys("shift+tab"),
			key.WithHelp("shift+tab", "prev pane"),
		),
		Run: key.NewBinding(
			key.WithKeys("x"),
			key.WithHelp("x", "run workflow"),
		),
		PickAPK: key.NewBinding(
			key.WithKeys("f"),
			key.WithHelp("f", "pick apk"),
		),
		SaveNote: key.NewBinding(
			key.WithKeys("ctrl+s"),
			key.WithHelp("ctrl+s", "save notes"),
		),
		Refresh: key.NewBinding(
			key.WithKeys("r"),
			key.WithHelp("r", "refresh demo data"),
		),
		Help: key.NewBinding(
			key.WithKeys("?"),
			key.WithHelp("?", "toggle help"),
		),
		Quit: key.NewBinding(
			key.WithKeys("q", "esc", "ctrl+c"),
			key.WithHelp("q", "quit"),
		),
	}
}

func buildStyles(dark bool) uiStyles {
	border := lipgloss.Color("63")
	accent := lipgloss.Color("86")
	muted := lipgloss.Color("241")
	warn := lipgloss.Color("214")
	good := lipgloss.Color("42")
	busy := lipgloss.Color("205")

	if !dark {
		border = lipgloss.Color("27")
		accent = lipgloss.Color("25")
		muted = lipgloss.Color("240")
		warn = lipgloss.Color("166")
		good = lipgloss.Color("28")
		busy = lipgloss.Color("161")
	}

	basePane := lipgloss.NewStyle().
		BorderStyle(lipgloss.RoundedBorder()).
		BorderForeground(border).
		Padding(0, 1)

	focused := basePane.Copy().BorderForeground(accent)

	return uiStyles{
		app: lipgloss.NewStyle().Padding(1, 1),
		header: lipgloss.NewStyle().
			Bold(true).
			Foreground(accent),
		headerRight: lipgloss.NewStyle().Foreground(muted),
		focusedPane: focused,
		pane:        basePane,
		footer:      lipgloss.NewStyle().Foreground(muted),
		modal: lipgloss.NewStyle().
			BorderStyle(lipgloss.DoubleBorder()).
			BorderForeground(accent).
			Padding(1, 2),
		statusOK:   lipgloss.NewStyle().Foreground(good),
		statusBusy: lipgloss.NewStyle().Foreground(busy),
		statusWarn: lipgloss.NewStyle().Foreground(warn),
	}
}

func initialModel() model {
	keys := defaultKeyMap()
	styles := buildStyles(true)

	workflows := []list.Item{
		workflowItem{
			title: "ADB device survey",
			desc:  "Inventory build, props, packages, users, and transports.",
			markdown: `Start with a clean device census and basic host ↔ device trust verification.

## Objectives
- Confirm the target transport.
- Capture Android version, build fingerprint, ABI, and security patch.
- Enumerate packages and split APK locations.
- Record multi-user state and debuggable posture.

## APDIF flow
1. adb devices -l
2. adb -s <serial> shell getprop
3. adb -s <serial> shell pm list packages -U -f
4. adb -s <serial> shell cmd package list users

## Why this matters
This view gives APDIF a stable baseline before deeper static or dynamic analysis.`,
		},
		workflowItem{
			title: "APK intake",
			desc:  "Pick an APK and prepare aapt2, jadx, and apktool stages.",
			markdown: `APDIF should treat APK intake as a reproducible pipeline, not a one-off drag-and-drop.

## Objectives
- Select the correct base APK or split package.
- Extract manifest metadata early.
- Route the sample into predictable lab directories.
- Generate first-pass notes for later Frida work.

## APDIF flow
1. Pick an APK.
2. Dump badging and permissions.
3. Queue jadx and apktool output directories.
4. Attach notes and evidence paths.

## Why this matters
A disciplined intake step prevents messy analysis trees and inconsistent paths later.`,
		},
		workflowItem{
			title: "Manifest triage",
			desc:  "Surface exported components, permissions, and deep-link edges.",
			markdown: `Manifest review is where the TUI should elevate high-signal issues fast.

## Objectives
- Identify exported activities, services, providers, and receivers.
- Compare declared permissions with real attack surface.
- Flag backup, cleartext, debuggable, and network security configuration.
- Prepare a shortlist for runtime validation.

## APDIF flow
1. Parse manifest.
2. Highlight exported components.
3. Flag risky capability combinations.
4. Emit next-step commands for validation.

## Why this matters
This is the bridge between static metadata and live exploitability testing.`,
		},
		workflowItem{
			title: "Frida session bootstrap",
			desc:  "Prepare a device-side hook run with clear operator notes.",
			markdown: `Dynamic work should open with a repeatable setup block.

## Objectives
- Confirm USB or TCP transport.
- Verify app package name and PID.
- Prepare a starter hook bundle.
- Record every loaded assumption in notes.

## APDIF flow
1. Confirm package and launchable activity.
2. Start or attach Frida.
3. Save baseline hook output.
4. Record detections and dead ends.

## Why this matters
The operator should be able to resume a session later without rebuilding state mentally.`,
		},
	}

	workflowList := list.New(workflows, list.NewDefaultDelegate(), 28, 14)
	workflowList.Title = "APDIF workflows"
	workflowList.SetShowStatusBar(false)
	workflowList.SetShowHelp(false)
	workflowList.SetShowPagination(false)
	workflowList.SetFilteringEnabled(true)

	columns := []table.Column{
		{Title: "Device", Width: 17},
		{Title: "State", Width: 10},
		{Title: "Transport", Width: 12},
		{Title: "Notes", Width: 26},
	}
	rows := []table.Row{
		{"ZT4228WHBQ", "device", "usb", "root testbed / primary"},
		{"emulator-5554", "offline", "tcp", "stale avd"},
		{"an-0k", "online", "tailscale", "android node"},
	}
	devicesTable := table.New(
		table.WithColumns(columns),
		table.WithRows(rows),
		table.WithFocused(true),
		table.WithHeight(10),
	)
	deviceStyles := table.DefaultStyles()
	deviceStyles.Header = deviceStyles.Header.Bold(true)
	deviceStyles.Selected = deviceStyles.Selected.Bold(true)
	devicesTable.SetStyles(deviceStyles)

	details := viewport.New(
		viewport.WithWidth(60),
		viewport.WithHeight(18),
	)

	notes := textarea.New()
	notes.Placeholder = "Operator notes: target package, exported paths, auth state, tokens, dead ends, exact commands..."
	notes.Focus()
	notes.SetWidth(80)
	notes.SetHeight(8)
	notes.SetStyles(textarea.DefaultStyles(true))

	picker := filepicker.New()
	picker.AllowedTypes = []string{".apk", ".apks", ".xapk", ".apkm"}
	picker.ShowPermissions = false
	picker.ShowSize = true
	picker.ShowHidden = false
	picker.CurrentDirectory, _ = os.UserHomeDir()

	spin := spinner.New()
	spin.Spinner = spinner.Dot
	spin.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	m := model{
		focus:        paneWorkflows,
		status:       "Ready. Select a workflow, a device, then run a canned APDIF step.",
		notesPath:    defaultNotesPath(),
		keys:         keys,
		help:         help.New(),
		styles:       styles,
		workflowList: workflowList,
		devicesTable: devicesTable,
		details:      details,
		notes:        notes,
		picker:       picker,
		spinner:      spin,
		dark:         true,
	}
	m.refreshDetails()
	return m
}

func defaultNotesPath() string {
	cfgDir, err := os.UserConfigDir()
	if err != nil {
		return "apdif-notes.md"
	}
	return filepath.Join(cfgDir, "apdif", "notes.md")
}

func (m model) Init() tea.Cmd {
	return tea.Batch(textarea.Blink, tea.RequestBackgroundColor)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.BackgroundColorMsg:
		m.dark = msg.IsDark()
		m.styles = buildStyles(m.dark)
		m.notes.SetStyles(textarea.DefaultStyles(m.dark))
		m.refreshDetails()
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ready = true
		m.resize()
	case actionCompleteMsg:
		m.running = false
		m.status = fmt.Sprintf("Completed %s on %s", msg.workflow, msg.device)
		m.logs = append([]string{msg.logLine}, m.logs...)
		m.refreshDetails()
	case savedNoteMsg:
		if msg.err != nil {
			m.status = fmt.Sprintf("save failed: %v", msg.err)
		} else {
			m.status = fmt.Sprintf("notes saved → %s", msg.path)
		}
		m.refreshDetails()
	case spinner.TickMsg:
		if m.running {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			cmds = append(cmds, cmd)
		}
	case tea.KeyPressMsg:
		if m.showPicker {
			switch {
			case key.Matches(msg, m.keys.Quit):
				m.showPicker = false
				m.status = "APK picker closed"
				return m, nil
			}
		} else {
			switch {
			case key.Matches(msg, m.keys.Quit):
				return m, tea.Quit
			case key.Matches(msg, m.keys.Help):
				m.help.ShowAll = !m.help.ShowAll
				return m, nil
			case key.Matches(msg, m.keys.FocusNext):
				m.nextFocus()
				return m, nil
			case key.Matches(msg, m.keys.FocusPrev):
				m.prevFocus()
				return m, nil
			case key.Matches(msg, m.keys.Refresh):
				m.status = "Demo inventory refreshed"
				m.refreshDetails()
				return m, nil
			case key.Matches(msg, m.keys.PickAPK):
				m.showPicker = true
				m.status = "Pick an APK for intake"
				return m, m.picker.Init()
			case key.Matches(msg, m.keys.SaveNote):
				return m, saveNoteCmd(m.notesPath, m.notes.Value())
			case key.Matches(msg, m.keys.Run):
				m.running = true
				m.status = fmt.Sprintf("Running %s", m.selectedWorkflow().title)
				cmds = append(cmds, runWorkflowCmd(m.selectedWorkflow(), m.selectedDevice(), m.selectedAPK), m.spinner.Tick)
			}
		}
	}

	if m.showPicker {
		var cmd tea.Cmd
		m.picker, cmd = m.picker.Update(msg)
		cmds = append(cmds, cmd)

		if didSelect, path := m.picker.DidSelectFile(msg); didSelect {
			m.selectedAPK = path
			m.showPicker = false
			m.status = fmt.Sprintf("APK selected → %s", filepath.Base(path))
			m.refreshDetails()
		}
		if didSelect, path := m.picker.DidSelectDisabledFile(msg); didSelect {
			m.status = fmt.Sprintf("unsupported file type → %s", path)
		}

		return m, tea.Batch(cmds...)
	}

	switch m.focus {
	case paneWorkflows:
		var cmd tea.Cmd
		m.workflowList, cmd = m.workflowList.Update(msg)
		cmds = append(cmds, cmd)
		m.refreshDetails()
	case paneDevices:
		var cmd tea.Cmd
		m.devicesTable, cmd = m.devicesTable.Update(msg)
		cmds = append(cmds, cmd)
		m.refreshDetails()
	case paneDetails:
		var cmd tea.Cmd
		m.details, cmd = m.details.Update(msg)
		cmds = append(cmds, cmd)
	case paneNotes:
		var cmd tea.Cmd
		m.notes, cmd = m.notes.Update(msg)
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m *model) nextFocus() {
	m.focus = (m.focus + 1) % 4
	m.syncFocusState()
}

func (m *model) prevFocus() {
	if m.focus == 0 {
		m.focus = 3
	} else {
		m.focus--
	}
	m.syncFocusState()
}

func (m *model) syncFocusState() {
	if m.focus == paneNotes {
		m.notes.Focus()
	} else {
		m.notes.Blur()
	}

	if m.focus == paneDevices {
		m.devicesTable.Focus()
	} else {
		m.devicesTable.Blur()
	}
}

func (m *model) resize() {
	if m.width <= 0 || m.height <= 0 {
		return
	}

	footerHeight := lipgloss.Height(m.help.View(m.keys))
	notesHeight := 10
	topHeight := max(12, m.height-notesHeight-footerHeight-5)

	leftWidth := max(28, min(38, m.width/4))
	centerWidth := max(34, min(48, m.width/3))
	rightWidth := max(42, m.width-leftWidth-centerWidth-8)

	m.workflowList.SetSize(leftWidth-4, topHeight-2)
	m.devicesTable.SetWidth(centerWidth - 4)
	m.devicesTable.SetHeight(topHeight - 2)

	m.detailsWidth = rightWidth - 4
	m.detailsHeight = topHeight - 2
	m.details.SetWidth(m.detailsWidth)
	m.details.SetHeight(m.detailsHeight)

	m.notes.SetWidth(max(20, m.width-6))
	m.notes.SetHeight(notesHeight - 2)
	m.picker.SetHeight(max(12, m.height-8))
	m.help.SetWidth(m.width - 4)

	m.refreshDetails()
}

func (m model) View() tea.View {
	if !m.ready {
		return tea.NewView("Loading APDIF…")
	}

	if m.showPicker {
		title := m.styles.header.Render("APDIF APK intake picker")
		helpLine := m.styles.footer.Render("enter: select   esc/q: close")
		content := lipgloss.JoinVertical(lipgloss.Left, title, "", m.picker.View(), "", helpLine)
		modal := m.styles.modal.
			Width(min(96, max(48, m.width-8))).
			Height(min(32, max(14, m.height-6))).
			Render(content)
		return tea.NewView(lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, modal))
	}

	headerLeft := m.styles.header.Render("APDIF") + "  " + m.styles.footer.Render("Android Permissions Debugging & Information Framework")
	statusText := m.status
	if m.running {
		statusText = fmt.Sprintf("%s %s", m.spinner.View(), m.status)
		statusText = m.styles.statusBusy.Render(statusText)
	} else if strings.Contains(strings.ToLower(m.status), "fail") || strings.Contains(strings.ToLower(m.status), "unsupported") {
		statusText = m.styles.statusWarn.Render(statusText)
	} else {
		statusText = m.styles.statusOK.Render(statusText)
	}
	header := lipgloss.JoinHorizontal(
		lipgloss.Top,
		headerLeft,
		strings.Repeat(" ", max(2, m.width-lipgloss.Width(headerLeft)-lipgloss.Width(statusText)-8)),
		m.styles.headerRight.Render(statusText),
	)

	workflowPane := m.renderPane(paneWorkflows, "Workflows", m.workflowList.View(), max(28, min(38, m.width/4)), max(12, m.height/2))
	devicePane := m.renderPane(paneDevices, "Devices", m.devicesTable.View(), max(34, min(48, m.width/3)), max(12, m.height/2))
	detailsPane := m.renderPane(paneDetails, "Details", m.details.View(), max(42, m.width/3), max(12, m.height/2))
	top := lipgloss.JoinHorizontal(lipgloss.Top, workflowPane, " ", devicePane, " ", detailsPane)

	notesHeader := fmt.Sprintf("Notes  %s", m.styles.footer.Render(m.notesPath))
	notesPane := m.renderPane(paneNotes, notesHeader, m.notes.View(), max(40, m.width-4), 10)

	footer := m.styles.footer.Render(m.help.View(m.keys))

	ui := lipgloss.JoinVertical(
		lipgloss.Left,
		header,
		"",
		top,
		"",
		notesPane,
		"",
		footer,
	)

	return tea.NewView(m.styles.app.Render(ui))
}

func (m model) renderPane(which pane, title, body string, width, height int) string {
	paneStyle := m.styles.pane
	if m.focus == which {
		paneStyle = m.styles.focusedPane
	}
	titleLine := m.styles.header.Render(title)
	content := lipgloss.JoinVertical(lipgloss.Left, titleLine, "", body)
	return paneStyle.Width(width).Height(height).Render(content)
}

func (m *model) refreshDetails() {
	wf := m.selectedWorkflow()
	dev := m.selectedDevice()
	cmdPreview := commandPreview(wf, dev, m.selectedAPK)

	notesPreview := strings.TrimSpace(m.notes.Value())
	if notesPreview == "" {
		notesPreview = "No notes yet. Use the notes pane to capture package names, exported surfaces, auth state, or runtime observations."
	}
	notesPreview = strings.ReplaceAll(notesPreview, "```", "'''")
	if len(notesPreview) > 500 {
		notesPreview = notesPreview[:500] + "…"
	}

	logBlock := "No workflow executions yet. Press x to simulate one."
	if len(m.logs) > 0 {
		logBlock = strings.Join(m.logs[:min(6, len(m.logs))], "\n")
	}

	apkLine := "No APK selected yet. Press f to open the file picker."
	if m.selectedAPK != "" {
		apkLine = fmt.Sprintf("`%s`", m.selectedAPK)
	}

	md := fmt.Sprintf(`# %s

%s

## Selected device
- **Serial:** %s
- **State:** %s
- **Transport:** %s
- **Notes:** %s

## Selected APK
%s

## APDIF command sketch

'text'
%s

'text'

## Recent run log

'text'
%s

'text'

## Notes snapshot

'text'
%s

'text'
`,
		wf.title,
		wf.markdown,
		dev[0],
		dev[1],
		dev[2],
		dev[3],
		apkLine,
		cmdPreview,
		logBlock,
		notesPreview,
	)

	md = strings.ReplaceAll(md, "\n'text'\n", "```text\n")
	md = strings.ReplaceAll(md, "\n'text'", "```")
	rendered := renderMarkdown(md, m.dark, max(48, m.detailsWidth))
	m.details.SetContent(rendered)
}

func (m model) selectedWorkflow() workflowItem {
	item, ok := m.workflowList.SelectedItem().(workflowItem)
	if !ok {
		return workflowItem{title: "Workflow", desc: "", markdown: ""}
	}
	return item
}

func (m model) selectedDevice() table.Row {
	row := m.devicesTable.SelectedRow()
	if len(row) < 4 {
		return table.Row{"unknown", "unknown", "unknown", "unknown"}
	}
	return row
}

func commandPreview(w workflowItem, device table.Row, apk string) string {
	serial := device[0]
	switch w.title {
	case "ADB device survey":
		return strings.Join([]string{
			fmt.Sprintf("adb -s %s get-state", serial),
			fmt.Sprintf("adb -s %s shell getprop ro.build.fingerprint", serial),
			fmt.Sprintf("adb -s %s shell pm list packages -U -f | sed -n '1,40p'", serial),
			fmt.Sprintf("adb -s %s shell cmd package list users", serial),
		}, "\n")
	case "APK intake":
		path := "</path/to/sample.apk>"
		if apk != "" {
			path = apk
		}
		return strings.Join([]string{
			fmt.Sprintf("mkdir -p ~/android-lab/{apk,out,jadx,apktool,notes}"),
			fmt.Sprintf("cp %q ~/android-lab/apk/", path),
			fmt.Sprintf("aapt2 dump badging %q", path),
			fmt.Sprintf("jadx -d ~/android-lab/jadx/%s %q", safeDir(filepath.Base(path)), path),
			fmt.Sprintf("apktool d -f -o ~/android-lab/apktool/%s %q", safeDir(filepath.Base(path)), path),
		}, "\n")
	case "Manifest triage":
		return strings.Join([]string{
			fmt.Sprintf("aapt2 dump xmltree %q AndroidManifest.xml | less", choosePath(apk)),
			fmt.Sprintf("rg -n \"exported|debuggable|allowBackup|networkSecurityConfig\" ~/android-lab/apktool/"),
			fmt.Sprintf("adb -s %s shell dumpsys package | sed -n '1,120p'", serial),
		}, "\n")
	case "Frida session bootstrap":
		return strings.Join([]string{
			fmt.Sprintf("adb -s %s shell pidof <package.name>", serial),
			fmt.Sprintf("frida-ps -Uai | rg <package.name>"),
			fmt.Sprintf("frida -U -f <package.name> -l hooks/base.js", serial),
		}, "\n")
	default:
		return fmt.Sprintf("adb -s %s shell getprop", serial)
	}
}

func choosePath(path string) string {
	if path == "" {
		return "</path/to/sample.apk>"
	}
	return path
}

func safeDir(name string) string {
	name = strings.TrimSuffix(name, filepath.Ext(name))
	name = strings.ReplaceAll(name, " ", "-")
	name = strings.ReplaceAll(name, "/", "-")
	return name
}

func renderMarkdown(md string, dark bool, width int) string {
	theme := "dark"
	if !dark {
		theme = "light"
	}

	r, err := glamour.NewTermRenderer(
		glamour.WithWordWrap(max(48, width)),
		glamour.WithStandardStyle(theme),
	)
	if err != nil {
		return md
	}
	out, err := r.Render(md)
	if err != nil {
		return md
	}
	return out
}

func saveNoteCmd(path, body string) tea.Cmd {
	return func() tea.Msg {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return savedNoteMsg{path: path, err: err}
		}
		err := os.WriteFile(path, []byte(body), 0o644)
		return savedNoteMsg{path: path, err: err}
	}
}

func runWorkflowCmd(w workflowItem, device table.Row, apk string) tea.Cmd {
	return func() tea.Msg {
		time.Sleep(900 * time.Millisecond)
		apkLabel := "no-apk"
		if apk != "" {
			apkLabel = filepath.Base(apk)
		}
		return actionCompleteMsg{
			workflow: w.title,
			device:   device[0],
			apk:      apk,
			logLine:  fmt.Sprintf("[%s] workflow=%s device=%s apk=%s", time.Now().Format(time.RFC3339), w.title, device[0], apkLabel),
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "apdif: %v\n", err)
		os.Exit(1)
	}
}
