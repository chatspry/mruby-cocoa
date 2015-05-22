//
//  BridgeSupport support
//
//  See Copyright Notice in cocoa.h
//


#include "cocoa_bridgesupport.h"
#include "cocoa_type.h"
#include "cocoa.h"
#include "cfunc.h"
#include "cfunc_struct.h"
#include "cfunc_pointer.h"

#include "mruby.h"
#include "mruby/string.h"
#include "mruby/variable.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

void
load_cocoa_bridgesupport(mrb_state *mrb,
    struct BridgeSupportStructTable *struct_table,
    struct BridgeSupportConstTable *const_table,
    struct BridgeSupportEnumTable *enum_table)
{
    struct cocoa_state *cs = cocoa_state(mrb);
    cs->struct_table = struct_table;
    cs->const_table = const_table;
    cs->enum_table = enum_table;
}


// Need to re-write to hash table
const char*
cocoa_bridgesupport_struct_lookup(mrb_state *mrb, const char *name)
{
    struct cocoa_state *cs = cocoa_state(mrb);
    if(cs->struct_table == NULL) {
        return NULL;
    }

    struct BridgeSupportStructTable *cur = cs->struct_table;
    while(cur->name) {
        if(strcmp(name, cur->name)==0) {
            return cur->definition;
        }
        ++cur;
    }
    return NULL;
}


mrb_value
cocoa_struct_const_missing(mrb_state *mrb, mrb_value klass)
{
    if(cocoa_state(mrb)->const_table == NULL) {
        return mrb_nil_value();
    }

    mrb_value name;
    mrb_get_args(mrb, "o", &name);
    char *namestr = mrb_string_value_ptr(mrb, name);

    const char *definition = cocoa_bridgesupport_struct_lookup(mrb, namestr);
    if(definition) {
        char *type = mrb_malloc(mrb, strlen(namestr) + 4);
        strcpy(type, "{");
        strcat(type, namestr);
        strcat(type, "=}");
        mrb_value strct = objc_type_to_cfunc_type(mrb, type);
        mrb_define_const(mrb, (struct RClass*)mrb_obj_ptr(klass), namestr, strct);
        return strct;
    }
    else {
        // todo: raise unknow struct exception
        printf("Unknown %s\n", namestr);
        return mrb_nil_value();
    }
}


mrb_value
cocoa_const_const_missing(mrb_state *mrb, mrb_value klass)
{
    struct cocoa_state *cs = cocoa_state(mrb);

    if(cs->const_table == NULL) {
        return mrb_nil_value();
    }

    mrb_value name;
    mrb_get_args(mrb, "o", &name);
    char *namestr = mrb_string_value_ptr(mrb, name);

    struct BridgeSupportConstTable *ccur = cs->const_table;
    while(ccur && ccur->name) {
        if(strcmp(namestr, ccur->name)==0) {
            mrb_value type = objc_type_to_cfunc_type(mrb, ccur->type);
            mrb_value ptr = cfunc_pointer_new_with_pointer(mrb, ccur->value, false);
            return mrb_funcall(mrb, type, "refer", 1, ptr);
        }
        ++ccur;
    }

    struct BridgeSupportEnumTable *ecur = cs->enum_table;
    while(ecur && ecur->name) {
        if(strcmp(namestr, ecur->name)==0) {
            struct cfunc_state *cfs = cfunc_state(mrb, NULL);
            struct cfunc_type_data *data;
            mrb_value val;

            switch(ecur->type) {
            case 's':
                val = mrb_funcall(mrb, mrb_obj_value(cfs->sint64_class), "new", 0);
                data = (struct cfunc_type_data*)DATA_PTR(val);
                data->value._sint64 = ecur->value.i64;
                return val;

            case 'u':
                val = mrb_funcall(mrb, mrb_obj_value(cfs->uint64_class), "new", 0);
                data = (struct cfunc_type_data*)DATA_PTR(val);
                data->value._uint64 = ecur->value.u64;
                return val;

            case 'd':
                val = mrb_funcall(mrb, mrb_obj_value(cfs->double_class), "new", 0);
                data = (struct cfunc_type_data*)DATA_PTR(val);
                data->value._double = ecur->value.dbl;
                return val;

            default:
                return mrb_nil_value();
            }
        }
        ++ecur;
    }

    return mrb_nil_value();
}


/*
 * initialize function
 */
void
init_cocoa_bridge_support(mrb_state *mrb, struct RClass* module)
{
    struct cocoa_state *cs = cocoa_state(mrb);

    struct RClass *struct_module = mrb_define_module_under(mrb, module, "Struct");
    mrb_define_class_method(mrb, struct_module, "const_missing", cocoa_struct_const_missing, ARGS_REQ(1));

    struct RClass *const_module = mrb_define_module_under(mrb, module, "Const");
    mrb_define_class_method(mrb, const_module, "const_missing", cocoa_const_const_missing, ARGS_REQ(1));
    mrb_define_class_method(mrb, const_module, "method_missing", cocoa_const_const_missing, ARGS_REQ(1));

    cs->struct_module = struct_module;
    cs->const_module = const_module;
    cs->const_table = NULL;
    cs->struct_table = NULL;
}
