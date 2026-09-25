// MXYZFCheat.m — 冒险与征途 3.0.6 (com.drsy.ios) Unity 2022.3.14f1 IL2CPP + HybridCLR
// 秒杀 / 无敌 / 全局加速 / 自动拾取 / 本地免伤调试开关 — 纯 il2cpp 导出 API 反射 invoke，零 RVA hook
//
// 挂点链（全部 Assembly-CSharp.dll 热更层实证，见 csharp_dump.txt）：
//   BattleElementCenter.gameObjectManager  [STATIC 字段] → GameObjectManager(战斗单位管理器)
//   GOM._unitList(List<IActionGameObject>: _items@0x10 _size@0x18 数据@0x20) → 全部战斗单位
//   GOM._player → 主角 SimpleCharacter；GOM.IsPlayerCamp(u)/IsOwnPlayer(u) → 敌我判定
//   单位继承链: Character→SimpleCharacter→ActiveGameObject→PassiveGameObject→InteractiveGameObject
//   IGO.get_interactiveGameObjectData() → IGOData.secondaryAttribute(字段) → SecondaryAttribute
//   秒杀: 敌方 SA.set_healthPointNow(0)（引擎 CheckDead 自然死亡，掉落/结算全真）
//   无敌: 己方 SA.set_healthPointNow(maxHp) 锁血 + IGO.Invincible(f,bool) 官方无敌
//   加速: UnityEngine.Time.set_timeScale(float)（引擎级全局）
//   拾取: BattleDropManager.set_PickAll(true) [STATIC 官方一键拾取]
//   调试: BattleElementCenter.set_localDamage(f)/set_localNoMiss(b) [STATIC 官方本地调试]
// 日志: Documents/mxzf.log
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <stdatomic.h>

static FILE *g_log = NULL;
static void mlog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void mlog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[MXZF] %@", s);
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/mxzf.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (g_log) { fprintf(g_log, "[MXZF] %s\n", s.UTF8String); fflush(g_log); }
}

#pragma mark - il2cpp API
static void *g_uf = NULL;
static void *p_domain_get, *p_domain_get_assemblies, *p_assembly_get_image, *p_image_get_name;
static void *p_class_from_name, *p_class_get_field_from_name, *p_class_get_method_from_name;
static void *p_field_get_offset, *p_field_static_get_value, *p_runtime_invoke;
static void *p_object_get_class, *p_class_get_name;
static void *p_image_get_class_count, *p_image_get_class, *p_class_get_namespace;

static BOOL load_il2cpp_api(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *im = _dyld_get_image_name(i);
        if (im && strstr(im, "UnityFramework")) {
            g_uf = dlopen(im, RTLD_NOW | RTLD_GLOBAL | RTLD_NOLOAD);
            if (g_uf) break;
        }
    }
    if (!g_uf) return NO;
    p_domain_get                 = dlsym(g_uf, "il2cpp_domain_get");
    p_domain_get_assemblies      = dlsym(g_uf, "il2cpp_domain_get_assemblies");
    p_assembly_get_image         = dlsym(g_uf, "il2cpp_assembly_get_image");
    p_image_get_name             = dlsym(g_uf, "il2cpp_image_get_name");
    p_class_from_name            = dlsym(g_uf, "il2cpp_class_from_name");
    p_class_get_field_from_name  = dlsym(g_uf, "il2cpp_class_get_field_from_name");
    p_class_get_method_from_name = dlsym(g_uf, "il2cpp_class_get_method_from_name");
    p_field_get_offset           = dlsym(g_uf, "il2cpp_field_get_offset");
    p_field_static_get_value     = dlsym(g_uf, "il2cpp_field_static_get_value");
    p_runtime_invoke             = dlsym(g_uf, "il2cpp_runtime_invoke");
    p_object_get_class           = dlsym(g_uf, "il2cpp_object_get_class");
    p_class_get_name             = dlsym(g_uf, "il2cpp_class_get_name");
    p_image_get_class_count      = dlsym(g_uf, "il2cpp_image_get_class_count");
    p_image_get_class            = dlsym(g_uf, "il2cpp_image_get_class");
    p_class_get_namespace        = dlsym(g_uf, "il2cpp_class_get_namespace");
    return p_runtime_invoke && p_class_from_name && p_domain_get && p_field_static_get_value;
}

#pragma mark - 内存探针
#import <mach/mach.h>
extern kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address,
    mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
static BOOL mx_readable(const void *p, uint64_t len) {
    if (!p || ((uintptr_t)p & 7)) return NO;
    char dummy[8];
    mach_vm_address_t outAddr = (mach_vm_address_t)(uintptr_t)dummy;
    mach_vm_size_t outSz = 0;
    kern_return_t kr = mach_vm_read_overwrite(mach_task_self(),
        (mach_vm_address_t)(uintptr_t)p, (mach_vm_size_t)len, outAddr, &outSz);
    return kr == KERN_SUCCESS;
}
// static_fields 就绪探测（Il2CppClass.static_fields @0xA8, metadata v29+）
static BOOL mx_static_safe(void *field) {
    if (!field || !mx_readable(field, 0x20)) return NO;
    void *parent = *(void**)((char*)field + 0x10);
    if (!parent || !mx_readable(parent, 0xC0)) return NO;
    void *sf = *(void**)((char*)parent + 0xA8);
    if (!sf || ((uintptr_t)sf & 7)) return NO;
    return mx_readable(sf, 0x40);
}

#pragma mark - invoke helper
static void *mx_invoke(void *method, void *inst, void **params) {
    if (!method) return NULL;
    void *exc = NULL;
    void *r = ((void*(*)(void*,void*,void**,void*))p_runtime_invoke)(method, inst, params, &exc);
    if (exc) {
        static int excN = 0;
        const char *cn = "?";
        void *cls = p_object_get_class ? ((void*(*)(void*))p_object_get_class)(exc) : NULL;
        if (cls && p_class_get_name) cn = ((const char*(*)(void*))p_class_get_name)(cls);
        if (excN++ < 8) mlog(@"invoke exc[%s]", cn);
        return NULL;
    }
    return r;
}
static void *mx_invoke2(void *method, void *inst) {
    if (!method) return NULL;
    void *exc = NULL;
    return ((void*(*)(void*,void*,void**,void*))p_runtime_invoke)(method, inst, NULL, &exc);
}
static long  mx_box_long (void *b) { return b ? *(long*)((char*)b + 0x10) : 0; }
static int   mx_box_int  (void *b) { return b ? *(int32_t*)((char*)b + 0x10) : 0; }
static BOOL  mx_box_bool (void *b) { return b ? *(uint8_t*)((char*)b + 0x10) : 0; }

static void *mx_cls(void *img, const char *ns, const char *name) {
    if (!img || !name) return NULL;
    // ⚠️ il2cpp_class_from_name 对 ns=NULL 会 strcmp 解引用崩溃 —— NULL 必须转空串
    if (!ns) ns = "";
    return ((void*(*)(void*,const char*,const char*))p_class_from_name)(img, ns, name);
}
static void *mx_meth(void *cls, const char *m, int argc) {
    return cls ? ((void*(*)(void*,const char*,int))p_class_get_method_from_name)(cls, m, argc) : NULL;
}
static void *mx_fptr(void *cls, const char *fname) {
    return cls ? ((void*(*)(void*,const char*))p_class_get_field_from_name)(cls, fname) : NULL;
}

// 全 image 扫描：HybridCLR 热更类注册在运行时加载的 image（名带 .dll 后缀）
// ⚠️ 热更程序集在游戏启动流程中后加载，image 列表不能永久缓存——rebuild=1 强制重建
static void **g_imgList = NULL;
static size_t g_imgCount = 0;
static void *g_imgBE = NULL;   // BattleElementCenter 所在 image（诊断）
static BOOL mx_cache_images(BOOL rebuild) {
    if (g_imgList && !rebuild) return YES;
    void *dom = ((void*(*)())p_domain_get)();
    if (!dom) return NO;
    size_t n = 0;
    void **list = ((void**(*)(void*,size_t*))p_domain_get_assemblies)(dom, &n);
    if (!list) return NO;
    static void *imgs[512];
    size_t c = 0;
    for (size_t i = 0; i < n && c < 512; i++) {
        if (!list[i]) continue;
        void *img = ((void*(*)(void*))p_assembly_get_image)(list[i]);
        if (img) imgs[c++] = img;
    }
    if (c == 0) return NO;
    g_imgList = imgs; g_imgCount = c;
    return YES;
}
// v1.4 安全扫描：不用 il2cpp_class_from_name（半初始化 image 会崩），
// 改用官方枚举 API image_get_class_count + image_get_class 逐类比对类名/命名空间。
// count 合法性校验 + 类指针探针双保险。
static BOOL mx_name_safe(const char *s) {
    return s && mx_readable(s, 8);
}
// v1.6 定位策略（枚举彻底死刑——.ips 两次实证 image_get_class 对 HybridCLR 热更 image 踩金丝雀）：
//   热更逻辑类全部位于 Assembly-CSharp(.dll) 主 image（csharp_dump.txt 14309 类实证）。
//   60s 门禁后 metadata 稳定，对热更 image 用 il2cpp_class_from_name 做【精确】查询是
//   HybridCLR 官方支持路径（hook 后走标准 lookup，无 typeStart 越界/无 lazy 缓存写）。
//   只有 Time 类去 UnityEngine.CoreModule 找。全程零枚举。
static void *mx_scan_all(const char *ns, const char *name) {
    if (!ns) ns = "";
    // 1) 主 image 精确查询（热更类全在这）
    if (g_imgMain) {
        void *c = mx_cls(g_imgMain, ns, name);
        if (c) {
            if (!strcmp(name, "BattleElementCenter")) g_imgBE = g_imgMain;
            return c;
        }
    }
    // 2) 兜底：逐 image class_from_name（精确查找，非枚举；稳定态安全）
    if (!mx_cache_images(NO)) return NULL;
    for (size_t i = 0; i < g_imgCount; i++) {
        void *img = g_imgList[i];
        if (!img || !mx_readable(img, 0x40)) continue;
        void *c = mx_cls(img, ns, name);
        if (c) {
            if (!strcmp(name, "BattleElementCenter")) g_imgBE = img;
            return c;
        }
    }
    return NULL;
}

// 值类型参数环形缓冲（runtime_invoke 值类型 = 未装箱数据指针，非装箱对象）
static int64_t g_al[16]; static int g_aln = 0;
static int32_t g_ai[16]; static int g_ain = 0;
static float   g_af[16]; static int g_afn = 0;
static uint8_t g_ab[16]; static int g_abn = 0;
static void *mx_argl(long v)  { int64_t *p = &g_al[g_aln++ & 15]; *p = v; return p; }
static void *mx_argi(int v)   { int32_t *p = &g_ai[g_ain++ & 15]; *p = v; return p; }
static void *mx_argf(float v) { float   *p = &g_af[g_afn++ & 15]; *p = v; return p; }
static void *mx_argb(BOOL v)  { uint8_t *p = &g_ab[g_abn++ & 15]; *p = v ? 1 : 0; return p; }

@interface MXBox : NSObject
+ (instancetype)shared;
- (void)noop;
- (void)tapMask;
- (void)tapKill;
- (void)tapInv;
- (void)tapSpd;
- (void)tapPick;
- (void)tapDbg;
- (void)tapBall;
- (void)dragBall:(UIPanGestureRecognizer *)g;
- (void)onTick;
@end


static void ui_refresh(void);

#pragma mark - 解析缓存
static void *g_imgMain;
static void *g_clsBE, *g_clsGOM, *g_clsIGO, *g_clsIGOData, *g_clsSecAttr, *g_clsDropMgr;
static void *g_clsTime;
static void *g_fGOM, *g_fIsOpen;
static void *g_mGetIsInBattle, *g_mUnitList, *g_mIsPlayerCamp, *g_mIsOwnPlayer;
static void *g_mIGOData, *m_SetHPNow, *g_mGetHPMax, *g_mInvincible, *g_mGetCamp;
static void *g_mSetPickAll, *g_mSetLocalDmg, *g_mSetNoMiss, *g_mTimeSet;
static int g_resolveTry = 0;
static BOOL g_resolved = NO;
static uint64_t g_bootMs = 0;   // 注入时刻
static BOOL g_phase2 = NO;      // 60s 后进入安全扫描期

static BOOL mx_resolve(void) {
    // v1.5 门禁：启动 60s 内 il2cpp 全局 metadata 在 HybridCLR 初始化中变化，
    // 枚举任何 image 都可能踩坏栈（v1.3/v1.4 .ips 实证）。60s 后游戏已进主城，热更 dll 必已加载。
    if (g_bootMs == 0) g_bootMs = (uint64_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
    uint64_t now = (uint64_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
    if (!g_phase2 && now - g_bootMs < 60000) {
        static int gateLog = 0;
        if (gateLog++ < 3) mlog(@"boot guard: waiting (%llu ms)", (unsigned long long)(now - g_bootMs));
        return NO;
    }
    if (!g_phase2) { g_phase2 = YES; mlog(@"boot guard passed, scanning starts"); }
    g_resolveTry++;
    if (g_resolveTry == 1 || g_resolveTry % 20 == 0) mlog(@"resolve try #%d", g_resolveTry);

    if (!g_imgMain) {
        void *dom = ((void*(*)())p_domain_get)();
        if (!dom) return NO;
        size_t n = 0;
        void **list = ((void**(*)(void*,size_t*))p_domain_get_assemblies)(dom, &n);
        if (!list) return NO;
        void *imgFP = NULL;   // Assembly-CSharp-firstpass（必须排除）
        for (size_t i = 0; i < n; i++) {
            if (!list[i]) continue;
            void *img = ((void*(*)(void*))p_assembly_get_image)(list[i]);
            if (!img) continue;
            const char *nm = ((const char*(*)(void*))p_image_get_name)(img);
            if (!nm) continue;
            // 运行时 image 名带 .dll 后缀；HybridCLR 热更程序集名不定 —— 只精确排除 firstpass
            if (!strcmp(nm, "Assembly-CSharp-firstpass.dll") || !strcmp(nm, "Assembly-CSharp-firstpass")) imgFP = img;
            else if (!strcmp(nm, "Assembly-CSharp.dll") || !strcmp(nm, "Assembly-CSharp")) g_imgMain = img;
        }
        // 【v1.2】image 名 gate 只作诊断——热更主程序集名运行时不一定叫 Assembly-CSharp(.dll)
        // 找不到也放行，全扫描负责真正定位
        if (g_imgMain) mlog(@"Assembly-CSharp image ok (fp=%p)", imgFP);
        else if (g_resolveTry % 20 == 0) mlog(@"Assembly-CSharp gate miss (fp=%p) -> full-scan path", imgFP);
    }

    if (!g_clsBE) {
        // 热更类可能注册在任意 image —— 全 image 兜底扫描（不 gate image 名）
        // ⚠️ HybridCLR 运行时 image 名带 .dll 后缀（Assembly-CSharp.dll）；
        //    热更 dll 后加载，image 列表必须失败时重建（不能永久缓存）
        if (!g_clsBE)    g_clsBE      = mx_scan_all("ActionGameLibrary", "BattleElementCenter");
        if (!g_clsGOM)   g_clsGOM     = mx_scan_all("ActionGameLibrary", "GameObjectManager");
        if (!g_clsIGO)   g_clsIGO     = mx_scan_all("ActionGameLibrary", "InteractiveGameObject");
        if (!g_clsIGOData) g_clsIGOData = mx_scan_all("ActionGameLibrary", "InteractiveGameObjectData");
        if (!g_clsSecAttr) g_clsSecAttr = mx_scan_all("ActionGameLibrary", "SecondaryAttribute");
        if (!g_clsDropMgr) g_clsDropMgr = mx_scan_all(NULL, "BattleDropManager");
        if (!g_clsTime)  g_clsTime    = mx_scan_all("UnityEngine", "Time");
        if (!g_clsBE || !g_clsGOM) {
            if (g_resolveTry % 20 == 0) {
                mlog(@"cls miss be=%p gom=%p imgs=%zu", g_clsBE, g_clsGOM, g_imgCount);
                if (mx_cache_images(YES)) {
                    NSMutableString *all = [NSMutableString string];
                    for (size_t i = 0; i < g_imgCount; i++) {
                        void *im = g_imgList[i];
                        const char *nm2 = im ? ((const char*(*)(void*))p_image_get_name)(im) : NULL;
                        int32_t tc = (im && mx_readable(im, 0x28)) ? *(int32_t*)((char*)im + 0x20) : -1;
                        [all appendFormat:@"%s(%d) ", nm2 ?: "?", tc];
                    }
                    mlog(@"images: %@", all);
                }
            }
            g_imgList = NULL;   // 强制下轮重建（等 HybridCLR 注册热更程序集）
            g_imgMain = NULL;   // image 名 gate 失败也放行——直接走全扫描
            return NO;
        }
        if (!g_clsIGO || !g_clsIGOData || !g_clsSecAttr || !g_clsDropMgr || !g_clsTime) {
            if (g_resolveTry % 20 == 0) mlog(@"cls2 miss igo=%p igod=%p sa=%p drop=%p time=%p", g_clsIGO, g_clsIGOData, g_clsSecAttr, g_clsDropMgr, g_clsTime);
            g_imgList = NULL;
            return NO;
        }
        mlog(@"classes resolved: BE in image %s", ((const char*(*)(void*))p_image_get_name)(g_imgBE) ?: "?");
    }

    g_fGOM        = mx_fptr(g_clsBE, "gameObjectManager");   // STATIC GameObjectManager
    g_fIsOpen     = mx_fptr(g_clsBE, "_isOpen");             // STATIC bool
    g_mGetIsInBattle = mx_meth(g_clsBE, "get_isInBattle", 0);// STATIC
    g_mUnitList   = mx_meth(g_clsGOM, "GetUnitList", 0);     // inst → List
    g_mIsPlayerCamp = mx_meth(g_clsGOM, "IsPlayerCamp", 1);  // inst
    g_mIsOwnPlayer  = mx_meth(g_clsGOM, "IsOwnPlayer", 1);   // inst
    if (!g_fGOM || !g_mGetIsInBattle || !g_mUnitList || !g_mIsPlayerCamp) {
        if (g_resolveTry % 20 == 0) mlog(@"gom meth miss fGOM=%p inbt=%p ul=%p pc=%p", g_fGOM, g_mGetIsInBattle, g_mUnitList, g_mIsPlayerCamp);
        return NO;
    }

    g_mIGOData    = mx_meth(g_clsIGO, "get_interactiveGameObjectData", 0);
    m_SetHPNow    = mx_meth(g_clsSecAttr, "set_healthPointNow", 1);
    g_mGetHPMax   = mx_meth(g_clsSecAttr, "get_healthPointCurMax", 0);
    g_mInvincible = mx_meth(g_clsIGO, "Invincible", 2);
    g_mGetCamp    = mx_meth(g_clsIGO, "get_camp", 0);
    if (!g_mIGOData || !m_SetHPNow || !g_mGetHPMax || !g_mGetCamp) {
        if (g_resolveTry % 20 == 0) mlog(@"attr meth miss igod=%p hp=%p max=%p camp=%p", g_mIGOData, m_SetHPNow, g_mGetHPMax, g_mGetCamp);
        return NO;
    }

    g_mSetPickAll  = mx_meth(g_clsDropMgr, "set_PickAll", 1);   // STATIC
    g_mSetLocalDmg = mx_meth(g_clsBE, "set_localDamage", 1);    // STATIC
    g_mSetNoMiss   = mx_meth(g_clsBE, "set_localNoMiss", 1);    // STATIC
    g_mTimeSet     = mx_meth(g_clsTime, "set_timeScale", 1);    // STATIC
    if (!g_mSetPickAll || !g_mTimeSet) {
        if (g_resolveTry % 20 == 0) mlog(@"meth2 miss pick=%p time=%p", g_mSetPickAll, g_mTimeSet);
        return NO;
    }

    if (!mx_static_safe(g_fGOM) || !mx_static_safe(g_fIsOpen)) {
        if (g_resolveTry % 20 == 0) mlog(@"static fields not ready");
        return NO;
    }

    g_resolved = YES;
    mlog(@"resolve OK try#%d", g_resolveTry);
    return YES;
}

#pragma mark - 开关状态
static atomic_int g_kill = 0;   // 秒杀
static atomic_int g_inv  = 0;   // 无敌
static atomic_int g_pick = 0;   // 自动拾取
static atomic_int g_spd = 0;  // 0=1x 1=2x 2=4x 3=8x
static const float SPD_N[4] = {1.0f, 2.0f, 4.0f, 8.0f};
static atomic_int g_dbg = 0;  // 本地免伤调试开关(官方 set_localDamage(0)+NoMiss)
static int g_killCnt = 0, g_lastKilled = 0, g_lastLocked = 0;
static int g_status = 0; // 0=未就绪 1=就绪 2=战斗中

// List<T> 布局: _items@0x10 _size@0x18; 数组: length@0x18 元素@0x20
static int mx_list_items(void *list, void **out, int max) {
    if (!list || !mx_readable(list, 0x20)) return 0;
    void *arr = *(void**)((char*)list + 0x10);
    if (!arr || !mx_readable(arr, 0x20)) return 0;
    int32_t n = *(int32_t*)((char*)arr + 0x18);
    if (n <= 0 || n > 4096) return 0;
    void **elems = (void**)((char*)arr + 0x20);
    if (!mx_readable(elems, (uint64_t)n * 8)) return 0;
    int c = 0;
    for (int i = 0; i < n && c < max; i++) if (elems[i]) out[c++] = elems[i];
    return c;
}

// 单位 → SecondaryAttribute
static void *mx_unit_sa(void *u) {
    if (!u || !mx_readable(u, 0x60)) return NULL;
    void *igod = mx_invoke2(g_mIGOData, u);
    if (!igod || !mx_readable(igod, 0x20)) return NULL;
    void *sa = *(void**)((char*)igod + 0x10);   // IGOData.secondaryAttribute 第一个实例字段@0x10
    if (!sa || !mx_readable(sa, 0x30)) return NULL;
    return sa;
}

#pragma mark - 主 tick（主线程 1s）
static void mx_tick(void) {
    @autoreleasepool {
        @try {
        if (!g_resolved && !mx_resolve()) { g_status = 0; return; }

        // 战斗判定: BE._isOpen static bool（战斗系统已开启）
        BOOL inBattle = NO;
        void *isOpenBox = mx_invoke2(g_mGetIsInBattle, NULL);
        if (isOpenBox) inBattle = mx_box_bool(isOpenBox);
        // _isOpen 直读兜底
        if (!inBattle) {
            // static field value
            char tmp[16] = {0};
            ((void(*)(void*,void*))p_field_static_get_value)(g_fIsOpen, tmp);
            inBattle = tmp[0] != 0;
        }
        g_status = inBattle ? 2 : 1;
        if (!inBattle) { ui_refresh(); return; }

        // GOM 实例（静态字段直读）
        void *gom = NULL;
        ((void(*)(void*,void*))p_field_static_get_value)(g_fGOM, &gom);
        if (!gom || !mx_readable(gom, 0x60)) return;

        // 全部单位
        void *unitList = mx_invoke2(g_mUnitList, gom);
        if (!unitList) return;
        void *units[1024];
        int n = mx_list_items(unitList, units, 1024);
        if (n <= 0) return;

        // 主角按 IsPlayerCamp/IsOwnPlayer 反射判定（GOM._player 偏移运行时不硬编码）
        int killed = 0, locked = 0;
        for (int i = 0; i < n; i++) {
            void *u = units[i];
            if (!u || !mx_readable(u, 0x60)) continue;

            BOOL mySide = FALSE;
            void *b = mx_invoke(g_mIsPlayerCamp, gom, (void*[]){u});
            if (b) mySide = mx_box_bool(b);

            void *sa = mx_unit_sa(u);
            if (!sa) continue;

            if (atomic_load(&g_kill) && !mySide) {
                // 秒杀：血量置 0 → CheckDead 自然死亡管线（sig: set_healthPointNow(int32)）
                mx_invoke(m_SetHPNow, sa, (void*[]){mx_argi(0)});
                killed++;
            }
            if (atomic_load(&g_inv) && mySide) {
                int maxHp = mx_box_int(mx_invoke2(g_mGetHPMax, sa));
                if (maxHp > 0) {
                    mx_invoke(m_SetHPNow, sa, (void*[]){mx_argi(maxHp)});
                    locked++;
                }
            }
        }
        if (killed) { g_killCnt += killed; }
        g_lastKilled = killed; g_lastLocked = locked;

        // 加速：Time.timeScale
        int spdv = atomic_load(&g_spd);
        if (spdv > 0) mx_invoke(g_mTimeSet, NULL, (void*[]){mx_argf(SPD_N[spdv])});
        // 拾取
        if (atomic_load(&g_pick)) mx_invoke(g_mSetPickAll, NULL, (void*[]){mx_argb(YES)});
        // 本地免伤调试
        if (atomic_load(&g_dbg)) {
            if (g_mSetLocalDmg) mx_invoke(g_mSetLocalDmg, NULL, (void*[]){mx_argf(0.0f)});
            if (g_mSetNoMiss)   mx_invoke(g_mSetNoMiss, NULL, (void*[]){mx_argb(YES)});
        }
        ui_refresh();
        } @catch (NSException *e) {
            mlog(@"tick exception: %@ %@", e.name, e.reason);
        }
    }
}

#pragma mark - UI
#define TAG_BALL  978001
#define TAG_PANEL 978002
#define TAG_ST    978003
#define TAG_MASK  978004
static UILabel *g_statusLabel = nil;
static UIButton *g_bKill = nil, *g_bInv = nil, *g_bSpd = nil, *g_bPick = nil, *g_bDbg = nil;
static void ui_toggle_panel(void);
static void mx_make_ui(void);

static UIColor *mx_color(int r, int g, int b, float a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}
static UIButton *mx_btn(NSString *title) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.layer.cornerRadius = 8;
    b.layer.borderWidth = 1;
    b.layer.borderColor = mx_color(90, 160, 255, 0.6).CGColor;
    b.backgroundColor = mx_color(28, 30, 40, 0.95);
    b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [b setTitleColor:mx_color(220, 225, 235, 1) forState:UIControlStateNormal];
    [b setTitle:title forState:UIControlStateNormal];
    return b;
}
static void mx_set_on(UIButton *b, BOOL on) {
    b.backgroundColor = on ? mx_color(24, 110, 60, 0.95) : mx_color(28, 30, 40, 0.95);
    b.layer.borderColor = (on ? mx_color(60, 220, 130, 0.9) : mx_color(90, 160, 255, 0.6)).CGColor;
}
static void ui_refresh(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_bKill) return;
        [g_bKill setTitle:[NSString stringWithFormat:@"秒杀  %@", atomic_load(&g_kill) ? @"开" : @"关"] forState:UIControlStateNormal];
        [g_bInv  setTitle:[NSString stringWithFormat:@"无敌  %@", atomic_load(&g_inv) ? @"开" : @"关"] forState:UIControlStateNormal];
        [g_bSpd  setTitle:[NSString stringWithFormat:@"加速  %gx", SPD_N[atomic_load(&g_spd)]] forState:UIControlStateNormal];
        [g_bPick setTitle:[NSString stringWithFormat:@"拾取  %@", atomic_load(&g_pick) ? @"开" : @"关"] forState:UIControlStateNormal];
        [g_bDbg  setTitle:[NSString stringWithFormat:@"免伤  %@", atomic_load(&g_dbg) ? @"开" : @"关"] forState:UIControlStateNormal];
        mx_set_on(g_bKill, atomic_load(&g_kill));
        mx_set_on(g_bInv,  atomic_load(&g_inv));
        mx_set_on(g_bSpd,  g_spd > 0);
        mx_set_on(g_bPick, atomic_load(&g_pick));
        mx_set_on(g_bDbg,  atomic_load(&g_dbg));
        NSString *st;
        if (g_status == 0)      st = @"状态：等待热更加载…";
        else if (g_status == 1) st = @"状态：就绪，进战斗生效";
        else {
            NSMutableString *m = [NSMutableString stringWithString:@"战斗中"];
            if (atomic_load(&g_kill) && g_lastKilled) [m appendFormat:@" 秒%d", g_lastKilled];
            if (atomic_load(&g_inv) && g_lastLocked) [m appendFormat:@" 锁%d", g_lastLocked];
            st = m;
        }
        g_statusLabel.text = st;
    });
}
static void ui_toggle_panel(void) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *p = [w viewWithTag:TAG_PANEL];
    if (p) {
        [[w viewWithTag:TAG_MASK] removeFromSuperview];
        [p removeFromSuperview];
        return;
    }
    CGFloat pw = 224, ph = 286;
    UIView *mask = [[UIView alloc] initWithFrame:w.bounds];
    mask.tag = TAG_MASK;
    mask.backgroundColor = [UIColor clearColor];
    mask.userInteractionEnabled = YES;
    [mask addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(tapMask)]];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(16, 70, pw, ph)];
    panel.tag = TAG_PANEL;
    panel.layer.cornerRadius = 14;
    panel.backgroundColor = mx_color(14, 16, 24, 0.92);
    panel.layer.borderColor = mx_color(70, 140, 255, 0.5).CGColor;
    panel.layer.borderWidth = 1;
    panel.userInteractionEnabled = YES;
    [panel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(noop)]];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, pw, 20)];
    title.text = @"✦ 征途助手 ✦";
    title.textColor = mx_color(120, 200, 255, 1);
    title.font = [UIFont boldSystemFontOfSize:15];
    title.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:title];

    void (^mk)(int, NSString *, void (^)()) = ^(int row, NSString *t, void (^act)()) {
        UIButton *b = mx_btn(t);
        b.frame = CGRectMake(12, 34 + row * 40, pw - 24, 34);
        [panel addSubview:b];
        act(b);
    };
    mk(0, @"秒杀  关", ^(UIButton *b){ g_bKill = b;
        [b addTarget:[MXBox shared] action:@selector(tapKill) forControlEvents:UIControlEventTouchUpInside]; });
    mk(1, @"无敌  关", ^(UIButton *b){ g_bInv = b;
        [b addTarget:[MXBox shared] action:@selector(tapInv) forControlEvents:UIControlEventTouchUpInside]; });
    mk(2, @"加速  1x", ^(UIButton *b){ g_bSpd = b;
        [b addTarget:[MXBox shared] action:@selector(tapSpd) forControlEvents:UIControlEventTouchUpInside]; });
    mk(3, @"拾取  关", ^(UIButton *b){ g_bPick = b;
        [b addTarget:[MXBox shared] action:@selector(tapPick) forControlEvents:UIControlEventTouchUpInside]; });
    mk(4, @"免伤  关", ^(UIButton *b){ g_bDbg = b;
        [b addTarget:[MXBox shared] action:@selector(tapDbg) forControlEvents:UIControlEventTouchUpInside]; });
    g_statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, ph - 24, pw - 20, 16)];
    g_statusLabel.tag = TAG_ST;
    g_statusLabel.textColor = mx_color(150, 160, 175, 1);
    g_statusLabel.font = [UIFont systemFontOfSize:10];
    g_statusLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:g_statusLabel];

    [w addSubview:mask];
    [w addSubview:panel];
    UIView *ball = [w viewWithTag:TAG_BALL];
    if (ball) [w bringSubviewToFront:ball];
    ui_refresh();
}
static void mx_make_ui(void) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    if (!w) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ mx_make_ui(); }); return; }
    if ([w viewWithTag:TAG_BALL]) return;
    UIButton *ball = [UIButton buttonWithType:UIButtonTypeCustom];
    ball.tag = TAG_BALL;
    ball.frame = CGRectMake(w.bounds.size.width - 76, 150, 48, 48);
    ball.backgroundColor = mx_color(20, 24, 36, 0.85);
    ball.layer.cornerRadius = 24;
    ball.layer.borderWidth = 1.5;
    ball.layer.borderColor = mx_color(80, 170, 255, 0.9).CGColor;
    [ball setTitle:@"征" forState:UIControlStateNormal];
    ball.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    [ball setTitleColor:mx_color(130, 210, 255, 1) forState:UIControlStateNormal];
    [ball addTarget:[MXBox shared] action:@selector(tapBall) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[MXBox shared] action:@selector(dragBall:)];
    [ball addGestureRecognizer:pan];
    [w addSubview:ball];
    mlog(@"UI ready");
}

#pragma mark - 事件盒
@implementation MXBox
+ (instancetype)shared { static MXBox *b; static dispatch_once_t o; dispatch_once(&o, ^{ b = [self new]; }); return b; }
- (void)noop {}
- (void)tapMask { ui_toggle_panel(); }
- (void)tapKill { atomic_fetch_xor(&g_kill, 1); mlog(@"kill -> %d", atomic_load(&g_kill)); ui_refresh(); }
- (void)tapInv  { atomic_fetch_xor(&g_inv, 1);  mlog(@"inv -> %d",  atomic_load(&g_inv));  ui_refresh(); }
- (void)tapSpd  { int nv = (atomic_load(&g_spd) + 1) % 4; atomic_store(&g_spd, nv); mlog(@"spd -> %gx", SPD_N[nv]); ui_refresh(); }
- (void)tapPick { atomic_fetch_xor(&g_pick, 1); mlog(@"pick -> %d", atomic_load(&g_pick)); ui_refresh(); }
- (void)tapDbg  { atomic_fetch_xor(&g_dbg, 1);  mlog(@"dbg -> %d",  atomic_load(&g_dbg));  ui_refresh(); }
- (void)tapBall { ui_toggle_panel(); }
- (void)dragBall:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}
- (void)onTick { mx_tick(); }
@end

#pragma mark - 启动
static NSTimer *g_timer = NULL;
static void mx_start_timer(void) {
    if (g_timer) return;
    g_timer = [NSTimer timerWithTimeInterval:1.0 target:[MXBox shared] selector:@selector(onTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:g_timer forMode:NSRunLoopCommonModes];
    mlog(@"timer started");
}
__attribute__((constructor)) static void mxzf_ctor(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        mlog(@"ctor pid=%d bid=%@", getpid(), bid);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!load_il2cpp_api()) { mlog(@"UnityFramework 未加载，静默退出"); return; }
            mlog(@"il2cpp api ok");
            mx_start_timer();
            mx_make_ui();
        });
    }
}
