//
//  initialize mruby-cocoa
// 
//  See Copyright Notice in cocoa.h
//

#include "cocoa.h"
#include "cocoa_object.h"
#include "cocoa_block.h"
#include "cocoa_obj_hook.h"
#include "cocoa_bridgesupport.h"
#include "cocoa_type.h"

#include "mruby.h"
#include "mruby/class.h"
#include "mruby/proc.h"
#include "mruby/value.h"
#include "mruby/dump.h"
#include "cfunc_pointer.h"

#import <Foundation/Foundation.h>
#include <setjmp.h>
#include "ffi.h"

size_t cocoa_state_offset = 0;


#define MAX_COCOA_MRB_STATE_COUNT 256

mrb_state **cocoa_mrb_states = NULL;
int cocoa_vm_count = 0;

/*
 * internal function
 */
static void
a_destructor(mrb_state *mrb, void *state)
{
    close_cocoa_module(mrb);
    //free(p);
}
/*
 * internal data
 */
static struct mrb_data_type a_data_type = {
    "a_object", a_destructor,
};



mrb_value
cocoa_mrb_state(mrb_state *mrb, mrb_value klass)
{
    return cfunc_pointer_new_with_pointer(mrb, mrb, false);
}

void
mrb_mruby_cocoa_gem_init(mrb_state *mrb)
{
    if(cocoa_vm_count >= MAX_COCOA_MRB_STATE_COUNT - 1) {
        puts("Too much open vm"); // TODO
    }

    if(cocoa_mrb_states == NULL) {
        cocoa_mrb_states = malloc(sizeof(mrb_state *) * MAX_COCOA_MRB_STATE_COUNT);
        for(int i = 0; i < MAX_COCOA_MRB_STATE_COUNT; ++i) {
            cocoa_mrb_states[i] = NULL;
        }
        cocoa_vm_count = 0;
    }
    cocoa_mrb_states[cocoa_vm_count++] = mrb;

    struct RClass *ns = mrb_define_module(mrb, "Cocoa");

    struct cocoa_state *cs = mrb_malloc(mrb, sizeof(struct cocoa_state));
    cs->namespace = ns;
    // printf("cs=%p, %p\n", cs, mrb->ud);

    // mrb_value mcs = mrb_voidp_value(cs);
    mrb_value mcs = mrb_obj_value(Data_Wrap_Struct(mrb, mrb->object_class, &a_data_type, cs));
    //mrb_value mcs = mrb_obj_value(cs);
    mrb_gv_set(mrb, mrb_intern(mrb, "$_cocoa_state"), mcs);

    init_objc_hook();
    init_cocoa_module_type(mrb, ns);
    init_cocoa_object(mrb, ns);
    init_cocoa_block(mrb, ns);
    init_cocoa_bridge_support(mrb, ns);
}

void
mrb_mruby_cocoa_gem_final(mrb_state *mrb)
{
}

void close_cocoa_module(mrb_state *mrb)
{
    int i = 0;
    while(cocoa_mrb_states[i] != mrb) {
        ++i;
    }
    memmove(&cocoa_mrb_states[i+1], &cocoa_mrb_states[i], sizeof(mrb_state *) * (MAX_COCOA_MRB_STATE_COUNT - i - 1));
    --cocoa_vm_count;
}
