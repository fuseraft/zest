/* A small native extension that tests/unit.kiwi installs as a package and loads through .zest/load.kiwi. */
#include "kiwi_ext.h"

static const KiwiApi* api;

static KiwiValue add(KiwiCtx* ctx, int argc, const KiwiValue* argv) {
    (void)argc;
    return api->new_int(ctx, api->to_int(ctx, argv[0]) + api->to_int(ctx, argv[1]));
}

KIWI_EXPORT int kiwi_ext_init(const KiwiApi* host, KiwiCtx* ctx) {
    if (host->abi_version < KIWI_ABI_VERSION) return 1;
    api = host;
    api->define(ctx, "add", add, 2);
    return 0;
}
