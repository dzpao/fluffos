// Written by danzipao@gmail.com on 2021/09/15
#include "base/package_api.h"

//
// limit_tune_on()
//
#ifdef F_LIMIT_TUNE_ON
void f_limit_tune_on() {
    if (!command_giver || !command_giver->interactive) {
        return;
    }

    if (command_giver->interactive->limit) {
        return;
    }

    command_giver->interactive->limit = 1;
}
#endif

//
// limit_tune_off()
//
#ifdef F_LIMIT_TUNE_OFF
void f_limit_tune_off() {
    if (!command_giver || !command_giver->interactive) {
        return;
    }

    if (!command_giver->interactive->limit) {
        return;
    }

    command_giver->interactive->limit = 0;
    maybe_schedule_user_command(command_giver->interactive);
}
#endif
