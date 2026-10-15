package workbench

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// These diagnostics assert the current observed behavior, including defects.
// Passing them confirms reproduction, not acceptance of that behavior.
func auditRequest(t *testing.T, s *Service, method, path, body, key string) *httptest.ResponseRecorder {
	t.Helper()
	token, _, err := s.login("admin", "Demo-Repair-2026!", "isolated-audit")
	if err != nil { t.Fatal(err) }
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("Authorization", "Bearer "+token)
	r.Header.Set("Idempotency-Key", key)
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w, r)
	return w
}

func TestAuditRestoreRevivesOrderLevelAuthorization(t *testing.T) {
	dir := t.TempDir()
	dataDir, key := filepath.Join(dir,"data"), filepath.Join(dir,"keys","storage.key")
	p, err := NewFilePersistence(dataDir,key)
	if err != nil { t.Fatal(err) }
	defer p.Close()
	s, err := New(p)
	if err != nil { t.Fatal(err) }
	backup := filepath.Join(dir,"backup.wbbak")
	if _, err = WriteBackup(p,key,backup); err != nil { t.Fatal(err) }
	mustAct(t,s,"dispatcher","wo_quote","handover_contact",map[string]any{"customerId":"customer-peer","reason":"synthetic handover"})
	mustAct(t,s,"dispatcher","wo_quote","assign",map[string]any{"assigneeId":"outsource"})
	current := testOrder(t,s,"wo_quote")
	if visible(current,testActor(s,"customer")) || visible(current,testActor(s,"engineer")) { t.Fatal("current revocation failed") }
	target := filepath.Join(dir,"restored")
	if err = RestoreBackup(backup,key,dataDir,target); err != nil { t.Fatal(err) }
	rp, err := NewFilePersistence(target,key)
	if err != nil { t.Fatal(err) }
	defer rp.Close()
	rs, err := New(rp)
	if err != nil { t.Fatal(err) }
	restored := testOrder(t,rs,"wo_quote")
	oldCustomer, newCustomer, oldEngineer := visible(restored,testActor(rs,"customer")), visible(restored,testActor(rs,"customer-peer")), visible(restored,testActor(rs,"engineer"))
	if !oldCustomer || newCustomer || !oldEngineer { t.Fatal("observed restoration behavior changed; reevaluate finding") }
	t.Logf("R01: latest old_customer=false old_engineer=false; restored old_customer=%v new_customer=%v old_engineer=%v",oldCustomer,newCustomer,oldEngineer)
}

func TestAuditQCCanReadFinanceFields(t *testing.T) {
	s,_ := testService(t)
	mustAct(t,s,"admin","wo_quote","cost",map[string]any{"category":"synthetic cost","amountCents":12000,"note":"synthetic finance note"})
	mustAct(t,s,"admin","wo_quote","commission",map[string]any{"person":"synthetic person","amountCents":5000,"note":"synthetic commission note"})
	o := s.view(testOrder(t,s,"wo_quote"),&s.state,testActor(s,"qc"))
	if len(o.Costs)!=1 || len(o.Commissions)!=1 { t.Fatal("observed field exposure changed; reevaluate finding") }
	if actionPermission("approve_cost",testActor(s,"qc"))==nil { t.Fatal("QC unexpectedly gained finance action") }
	t.Logf("R02: QC approve_cost=denied; readable costs=%d commissions=%d",len(o.Costs),len(o.Commissions))
}

func TestAuditExportDoesNotPersistAudit(t *testing.T) {
	s,p := testService(t)
	before := append([]byte(nil),p.data...)
	saves := p.saves
	w := auditRequest(t,s,http.MethodGet,"/api/v38/export","","export-audit")
	if w.Code!=200 { t.Fatalf("export status %d",w.Code) }
	if !bytes.Equal(before,p.data) || saves!=p.saves { t.Fatal("export began persisting a record; reevaluate finding") }
	t.Logf("R03: export status=%d; persistent saves delta=%d; snapshot unchanged=true",w.Code,p.saves-saves)
}

func TestAuditAccountChangeDiscardsReason(t *testing.T) {
	s,p := testService(t)
	marker := "SYNTHETIC-UNIQUE-STATUS-REASON-20261014"
	body,_ := json.Marshal(map[string]string{"status":"disabled","reason":marker})
	w := auditRequest(t,s,http.MethodPost,"/api/v38/accounts/customer/status",string(body),"status-reason")
	if w.Code!=200 || testActor(s,"customer").Status!="disabled" { t.Fatalf("status update failed %d",w.Code) }
	if bytes.Contains(p.data,[]byte(marker)) { t.Fatal("reason is now persisted; reevaluate finding") }
	t.Logf("R04: account disabled=true; submitted reason persisted=false; idempotency entries=%d",len(s.state.Requests))
}

func TestAuditIdempotencyArchiveBlocksAllNewWrites(t *testing.T) {
	s,p := testService(t)
	for i:=0;i<10000;i++ { s.state.Requests[fmt.Sprintf("synthetic-%d",i)]=CachedRequest{} }
	before := s.state.Settings.ReminderHours
	saves := p.saves
	_,_,err := s.transact(testActor(s,"admin"),"POST /settings","new-settings",[]byte(`{"reminderHours":17}`),200,func(st *State)(any,error){st.Settings.ReminderHours=17;return st.Settings,nil})
	expectCode(t,err,"request_archive_full")
	if s.state.Settings.ReminderHours!=before || p.saves!=saves { t.Fatal("rejected change was persisted") }
	t.Log("R07: 10000 archived keys reject unrelated new settings write; no change committed")
}

func TestAuditBrowserCrossOriginConfiguration(t *testing.T) {
	s,_ := testService(t)
	r := httptest.NewRequest("OPTIONS","/api/v38/bootstrap",nil)
	r.Header.Set("Origin","http://127.0.0.1:8099")
	r.Header.Set("Access-Control-Request-Headers","authorization,content-type")
	w := httptest.NewRecorder()
	s.Handler("").ServeHTTP(w,r)
	if !strings.Contains(w.Header().Get("Content-Security-Policy"),"connect-src 'self'") || w.Header().Get("Access-Control-Allow-Origin")!="" || w.Code!=405 { t.Fatal("cross-origin policy changed; reevaluate finding") }
	t.Logf("R06: connect-src=self; preflight status=%d; allow-origin absent=true",w.Code)
}

func TestAuditBootstrapGrowth(t *testing.T) {
	s,_ := testService(t)
	base := testOrder(t,s,"wo_quote")
	for _,n:=range []int{10,100,1000} {
		s.state.Orders=make([]Order,n)
		for i:=range s.state.Orders { s.state.Orders[i]=cloneOrder(base);s.state.Orders[i].ID=fmt.Sprintf("wo_synthetic_%d",i) }
		start:=time.Now()
		raw,err:=json.Marshal(s.bootstrap(testActor(s,"admin")))
		if err!=nil { t.Fatal(err) }
		t.Logf("R08: synthetic orders=%d bootstrap_bytes=%d elapsed_ms=%.3f",n,len(raw),float64(time.Since(start).Microseconds())/1000)
	}
}
