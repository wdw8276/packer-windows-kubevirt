package main

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

type Command struct {
	Name string `json:"name"`
	Cmd  string `json:"cmd"`
}

type Config struct {
	host     string
	port     int
	username string
	password string
	https    bool
	retries  int
	commands string
	kms      string
	ipk      string
}

func newClient(cfg *Config) *http.Client {
	if cfg.https {
		return &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
		}
	}
	return &http.Client{}
}

func winrmPost(cfg *Config, client *http.Client, body string) (string, error) {
	scheme := "http"
	if cfg.https {
		scheme = "https"
	}
	url := fmt.Sprintf("%s://%s:%d/wsman", scheme, cfg.host, cfg.port)

	req, _ := http.NewRequest("POST", url, bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/soap+xml;charset=UTF-8")
	req.Header.Set("Connection", "close")

	if cfg.https {
		creds := base64.StdEncoding.EncodeToString([]byte(cfg.username + ":" + cfg.password))
		req.Header.Set("Authorization", "Basic "+creds)
	} else {
		req.SetBasicAuth(cfg.username, cfg.password)
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	return string(data), nil
}

func endpoint(cfg *Config) string {
	scheme := "http"
	if cfg.https {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s:%d/wsman", scheme, cfg.host, cfg.port)
}

func createShell(cfg *Config, client *http.Client) (string, error) {
	body := fmt.Sprintf(`<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
    xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing"
    xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Header>
    <a:To>%s</a:To>
    <a:ReplyTo><a:Address s:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address></a:ReplyTo>
    <a:Action s:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/09/transfer/Create</a:Action>
    <w:MaxEnvelopeSize s:mustUnderstand="true">153600</w:MaxEnvelopeSize>
    <a:MessageID>uuid:00000000-0000-0000-0000-000000000001</a:MessageID>
    <w:Locale xml:lang="en-US" s:mustUnderstand="false"/>
    <w:ResourceURI s:mustUnderstand="true">http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd</w:ResourceURI>
    <w:OperationTimeout>PT60S</w:OperationTimeout>
  </s:Header>
  <s:Body><rsp:Shell xmlns:rsp="http://schemas.microsoft.com/wbem/wsman/1/windows/shell">
    <rsp:InputStreams>stdin</rsp:InputStreams>
    <rsp:OutputStreams>stdout stderr</rsp:OutputStreams>
  </rsp:Shell></s:Body>
</s:Envelope>`, endpoint(cfg))

	resp, err := winrmPost(cfg, client, body)
	if err != nil {
		return "", err
	}
	m := regexp.MustCompile(`<rsp:ShellId>(.*?)</rsp:ShellId>`).FindStringSubmatch(resp)
	if len(m) < 2 {
		n := min(300, len(resp))
		return "", fmt.Errorf("no ShellId in response: %s", resp[:n])
	}
	return m[1], nil
}

func runCommand(cfg *Config, client *http.Client, shellID, cmd string) (string, error) {
	body := fmt.Sprintf(`<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
    xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing"
    xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd"
    xmlns:rsp="http://schemas.microsoft.com/wbem/wsman/1/windows/shell">
  <s:Header>
    <a:To>%s</a:To>
    <a:ReplyTo><a:Address s:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address></a:ReplyTo>
    <a:Action s:mustUnderstand="true">http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Command</a:Action>
    <w:MaxEnvelopeSize s:mustUnderstand="true">153600</w:MaxEnvelopeSize>
    <a:MessageID>uuid:00000000-0000-0000-0000-000000000002</a:MessageID>
    <w:Locale xml:lang="en-US" s:mustUnderstand="false"/>
    <w:ResourceURI s:mustUnderstand="true">http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd</w:ResourceURI>
    <w:SelectorSet><w:Selector Name="ShellId">%s</w:Selector></w:SelectorSet>
    <w:OperationTimeout>PT60S</w:OperationTimeout>
  </s:Header>
  <s:Body><rsp:CommandLine><rsp:Command>%s</rsp:Command></rsp:CommandLine></s:Body>
</s:Envelope>`, endpoint(cfg), shellID, cmd)

	resp, err := winrmPost(cfg, client, body)
	if err != nil {
		return "", err
	}
	m := regexp.MustCompile(`<rsp:CommandId>(.*?)</rsp:CommandId>`).FindStringSubmatch(resp)
	if len(m) < 2 {
		n := min(300, len(resp))
		return "", fmt.Errorf("no CommandId: %s", resp[:n])
	}
	return m[1], nil
}

func receiveOutput(cfg *Config, client *http.Client, shellID, cmdID string) (string, string, error) {
	body := fmt.Sprintf(`<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
    xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing"
    xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd"
    xmlns:rsp="http://schemas.microsoft.com/wbem/wsman/1/windows/shell">
  <s:Header>
    <a:To>%s</a:To>
    <a:ReplyTo><a:Address s:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address></a:ReplyTo>
    <a:Action s:mustUnderstand="true">http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Receive</a:Action>
    <w:MaxEnvelopeSize s:mustUnderstand="true">153600</w:MaxEnvelopeSize>
    <a:MessageID>uuid:00000000-0000-0000-0000-000000000003</a:MessageID>
    <w:Locale xml:lang="en-US" s:mustUnderstand="false"/>
    <w:ResourceURI s:mustUnderstand="true">http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd</w:ResourceURI>
    <w:SelectorSet><w:Selector Name="ShellId">%s</w:Selector></w:SelectorSet>
    <w:OperationTimeout>PT60S</w:OperationTimeout>
  </s:Header>
  <s:Body><rsp:Receive><rsp:DesiredStream CommandId="%s">stdout stderr</rsp:DesiredStream></rsp:Receive></s:Body>
</s:Envelope>`, endpoint(cfg), shellID, cmdID)

	resp, err := winrmPost(cfg, client, body)
	if err != nil {
		return "", "", err
	}

	decode := func(pattern string) string {
		re := regexp.MustCompile(pattern)
		var buf strings.Builder
		for _, m := range re.FindAllStringSubmatch(resp, -1) {
			if len(m) > 1 && m[1] != "" {
				b, _ := base64.StdEncoding.DecodeString(m[1])
				buf.Write(b)
			}
		}
		return buf.String()
	}

	return decode(`<rsp:Stream Name="stdout"[^>]*>(.*?)</rsp:Stream>`),
		decode(`<rsp:Stream Name="stderr"[^>]*>(.*?)</rsp:Stream>`),
		nil
}

// execCmd runs a single command and prints output. Returns stdout and rc (-1 on error).
func execCmd(cfg *Config, name, cmd string) (string, int) {
	fmt.Printf("\n=== %s ===\n", name)
	var lastErr error
	for attempt := 0; attempt < cfg.retries; attempt++ {
		client := newClient(cfg)
		shellID, err := createShell(cfg, client)
		if err != nil {
			lastErr = fmt.Errorf("createShell: %w", err)
			time.Sleep(3 * time.Second)
			continue
		}
		cmdID, err := runCommand(cfg, client, shellID, cmd)
		if err != nil {
			lastErr = fmt.Errorf("runCommand: %w", err)
			time.Sleep(3 * time.Second)
			continue
		}
		stdout, stderr, err := receiveOutput(cfg, client, shellID, cmdID)
		if err != nil {
			lastErr = fmt.Errorf("receiveOutput: %w", err)
			time.Sleep(3 * time.Second)
			continue
		}
		if stdout != "" {
			fmt.Print(strings.TrimRight(stdout, "\r\n"))
			fmt.Println()
		}
		if stderr != "" {
			fmt.Printf("[stderr] %s\n", strings.TrimRight(stderr, "\r\n"))
		}
		return stdout, 0
	}
	fmt.Printf("[ERROR] %v\n", lastErr)
	return "", -1
}

func activateKMS(cfg *Config) {
	kms := cfg.kms
	var kmsHost, kmsPort string
	if idx := strings.LastIndex(kms, ":"); idx != -1 {
		kmsHost, kmsPort = kms[:idx], kms[idx+1:]
	} else {
		kmsHost, kmsPort = kms, "1688"
		kms = kms + ":1688"
	}

	fmt.Printf("\n=== KMS Activation (%s) ===\n", kms)

	// Optional: install product key first
	if cfg.ipk != "" {
		execCmd(cfg, "install product key",
			fmt.Sprintf(`powershell -Command "cscript C:\Windows\System32\slmgr.vbs /ipk %s"`, cfg.ipk))
	}

	// Check KMS server connectivity
	out, _ := execCmd(cfg, fmt.Sprintf("KMS connectivity %s:%s", kmsHost, kmsPort),
		fmt.Sprintf(`powershell -Command "$r = Test-NetConnection -ComputerName %s -Port %s; Write-Output $r.TcpTestSucceeded"`,
			kmsHost, kmsPort))
	if !strings.Contains(out, "True") {
		fmt.Printf("[ERROR] KMS server %s is unreachable, aborting\n", kms)
		os.Exit(1)
	}
	fmt.Printf("[OK] KMS server %s is reachable\n", kms)

	// Set KMS server
	execCmd(cfg, "set KMS server",
		fmt.Sprintf(`powershell -Command "cscript C:\Windows\System32\slmgr.vbs /skms %s"`, kms))

	// Activate with 30s timeout
	atoCmd := `powershell -Command "$job = Start-Job { cscript C:\Windows\System32\slmgr.vbs /ato }; ` +
		`$done = Wait-Job $job -Timeout 30; ` +
		`if ($done) { Receive-Job $job } else { Stop-Job $job; Write-Output 'ERROR: KMS activation timed out' }"`
	execCmd(cfg, "activate (timeout 30s)", atoCmd)

	// Show license status
	execCmd(cfg, "license status",
		`powershell -Command "cscript C:\Windows\System32\slmgr.vbs /dli"`)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

var sampleCommands = []Command{
	{Name: "hostname", Cmd: "hostname"},
	{Name: "whoami", Cmd: "whoami"},
	{Name: "system info", Cmd: `powershell -Command "$r = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $mem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB, 1); $cpu = (Get-CimInstance Win32_Processor).Name; $os = Get-CimInstance Win32_OperatingSystem; $uptime = (Get-Date) - $os.LastBootUpTime; [PSCustomObject]@{ ProductName=$os.Caption; DisplayVersion=$r.DisplayVersion; BuildNumber=$r.CurrentBuildNumber; Architecture=$os.OSArchitecture; CPU=$cpu; MemoryGB=$mem; LastBootTime=$os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'); UptimeMinutes=[math]::Round($uptime.TotalMinutes) } | Format-List | Out-String -Width 200"`},
	{Name: "network adapters", Cmd: `powershell -Command "Get-NetAdapter | Format-Table -AutoSize Name, InterfaceDescription, Status, MacAddress, LinkSpeed | Out-String -Width 200"`},
	{Name: "ip config", Cmd: `powershell -Command "Get-NetIPConfiguration | Format-Table -AutoSize InterfaceAlias, InterfaceDescription, IPv4Address, IPv4DefaultGateway | Out-String -Width 200"`},
	{Name: "disk info", Cmd: `powershell -Command "Get-Disk | Format-Table -AutoSize Number, FriendlyName, Size, PartitionStyle, OperationalStatus | Out-String -Width 200"`},
	{Name: "partitions", Cmd: `powershell -Command "Get-Partition | Format-Table -AutoSize DiskNumber, PartitionNumber, Type, Size, DriveLetter, IsActive | Out-String -Width 200"`},
	{Name: "wuauserv service", Cmd: "sc query wuauserv"},
	{Name: "wuauserv startup type", Cmd: "sc qc wuauserv"},
	{Name: "wuauserv registry Start", Cmd: `reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start`},
	{Name: "NoAutoUpdate policy", Cmd: `reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2>nul || echo NOT_SET`},
	{Name: "DisableWindowsUpdate task", Cmd: "schtasks /query /tn DisableWindowsUpdate /fo LIST"},
	{Name: "DisableWindowsUpdate last run", Cmd: `powershell -Command "Get-ScheduledTaskInfo -TaskName DisableWindowsUpdate | Select-Object LastRunTime, LastTaskResult | Format-List"`},
	{Name: "WaaSMedicSvc config", Cmd: "sc qc WaaSMedicSvc"},
	{Name: "WaaSMedicSvc status", Cmd: "sc query WaaSMedicSvc"},
	{Name: "defragsvc status", Cmd: "sc query defragsvc"},
	{Name: "defragsvc startup type", Cmd: "sc qc defragsvc"},
}

func initCommands(path string) {
	if _, err := os.Stat(path); err == nil {
		fmt.Fprintf(os.Stderr, "error: %s already exists, will not overwrite\n", path)
		os.Exit(1)
	}
	data, err := json.MarshalIndent(sampleCommands, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "error writing %s: %v\n", path, err)
		os.Exit(1)
	}
	fmt.Printf("created %s with %d sample commands\n", path, len(sampleCommands))
}

func main() {
	cfg := &Config{}
	var initFile string
	flag.StringVar(&cfg.host, "host", "", "WinRM host (required)")
	flag.IntVar(&cfg.port, "port", 5986, "WinRM port (5986=HTTPS, 5985=HTTP)")
	flag.StringVar(&cfg.username, "user", "vagrant", "username")
	flag.StringVar(&cfg.password, "pass", "", "password (required)")
	flag.BoolVar(&cfg.https, "https", true, "use HTTPS with Basic auth; set false for HTTP")
	flag.IntVar(&cfg.retries, "retries", 6, "retry count on failure")
	flag.StringVar(&cfg.commands, "commands", "commands.json", "path to commands JSON file")
	flag.StringVar(&cfg.kms, "kms", "", "KMS server for activation (e.g. 10.1.2.3 or 10.1.2.3:1688)")
	flag.StringVar(&cfg.ipk, "ipk", "", "product key to install before KMS activation (optional)")
	flag.StringVar(&initFile, "init", "", "generate a sample commands JSON file at the given path and exit")
	flag.Parse()

	if initFile != "" {
		initCommands(initFile)
		return
	}

	if cfg.host == "" {
		fmt.Fprintln(os.Stderr, "error: -host is required")
		os.Exit(1)
	}
	if cfg.password == "" {
		fmt.Fprintln(os.Stderr, "error: -pass is required")
		os.Exit(1)
	}

	if cfg.kms != "" {
		activateKMS(cfg)
		return
	}

	data, err := os.ReadFile(cfg.commands)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading commands file: %v\n", err)
		os.Exit(1)
	}
	var commands []Command
	if err := json.Unmarshal(data, &commands); err != nil {
		fmt.Fprintf(os.Stderr, "error parsing commands file: %v\n", err)
		os.Exit(1)
	}

	for _, c := range commands {
		execCmd(cfg, c.Name, c.Cmd)
	}
}
