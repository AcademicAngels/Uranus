package controller

import (
	"testing"

	v1beta1 "github.com/hiclaw/hiclaw-controller/api/v1beta1"
	"github.com/hiclaw/hiclaw-controller/internal/backend"
)

func TestEffectiveExposePorts_DefaultHermesExposesWebUI(t *testing.T) {
	got := effectiveExposePorts(
		MemberDeps{DefaultRuntime: backend.RuntimeHermes},
		MemberContext{Spec: v1beta1.WorkerSpec{}},
	)

	if len(got) != 1 || got[0].Port != 6060 {
		t.Fatalf("effectiveExposePorts() = %+v, want port 6060 for default Hermes runtime", got)
	}
}

func TestEffectiveExposePorts_ExplicitHermesExposesWebUI(t *testing.T) {
	got := effectiveExposePorts(
		MemberDeps{DefaultRuntime: backend.RuntimeOpenClaw},
		MemberContext{Spec: v1beta1.WorkerSpec{Runtime: backend.RuntimeHermes}},
	)

	if len(got) != 1 || got[0].Port != 6060 {
		t.Fatalf("effectiveExposePorts() = %+v, want port 6060 for explicit Hermes runtime", got)
	}
}

func TestEffectiveExposePorts_ExplicitExposeOverridesHermesDefault(t *testing.T) {
	got := effectiveExposePorts(
		MemberDeps{DefaultRuntime: backend.RuntimeHermes},
		MemberContext{Spec: v1beta1.WorkerSpec{
			Expose: []v1beta1.ExposePort{{Port: 3000}},
		}},
	)

	if len(got) != 1 || got[0].Port != 3000 {
		t.Fatalf("effectiveExposePorts() = %+v, want explicit port 3000 only", got)
	}
}

func TestEffectiveExposePorts_NonHermesHasNoImplicitExpose(t *testing.T) {
	got := effectiveExposePorts(
		MemberDeps{DefaultRuntime: backend.RuntimeOpenClaw},
		MemberContext{Spec: v1beta1.WorkerSpec{}},
	)

	if got != nil {
		t.Fatalf("effectiveExposePorts() = %+v, want nil for non-Hermes runtime", got)
	}
}
