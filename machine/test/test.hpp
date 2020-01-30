#ifndef RBX_TEST_TEST_HPP
#define RBX_TEST_TEST_HPP

#include "vm.hpp"
#include "state.hpp"
#include "call_frame.hpp"
#include "config_parser.hpp"
#include "machine.hpp"
#include "environment.hpp"
#include "machine/object_utils.hpp"
#include "memory.hpp"
#include "configuration.hpp"
#include "machine/detection.hpp"
#include "class/executable.hpp"
#include "class/method_table.hpp"
#include "class/thread.hpp"

#include <cxxtest/TestSuite.h>

using namespace rubinius;

class RespondToToAry {
public:
  template <class T>
    static Object* create(STATE) {
      Class* klass = Class::create(state, G(object));

      Symbol* to_ary_sym = state->symbol("to_ary");
      Executable* to_ary = Executable::allocate(state, cNil);
      to_ary->primitive(state, to_ary_sym);
      to_ary->set_executor(T::to_ary);

      klass->method_table()->store(state, to_ary_sym, nil<String>(), to_ary,
          nil<LexicalScope>(), Fixnum::from(0), G(sym_public));

      Object* obj = state->memory()->new_object<Object>(state, klass);

      return obj;
    }
};

class RespondToToAryReturnNull : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnNull>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return nullptr;
  }
};

class RespondToToAryReturnFixnum : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnFixnum>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return Fixnum::from(42);
  }
};

class RespondToToAryReturnArray : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnArray>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    Array* ary = Array::create(state, 1);
    ary->set(state, 0, Fixnum::from(42));

    return ary;
  }
};

class RespondToToAryReturnNonArray : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnNonArray>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return Fixnum::from(42);
  }
};

class RespondToToS {
public:
  template <class T>
    static Object* create(STATE) {
      Class* klass = Class::create(state, G(object));

      Symbol* to_s_sym = state->symbol("to_s");
      Executable* to_s = Executable::allocate(state, cNil);
      to_s->primitive(state, to_s_sym);
      to_s->set_executor(T::to_s);

      klass->method_table()->store(state, to_s_sym, nil<String>(), to_s,
          nil<LexicalScope>(), Fixnum::from(0), G(sym_public));

      Object* obj = state->memory()->new_object<Object>(state, klass);

      return obj;
    }
};

class RespondToToSReturnString : public RespondToToS {
public:
  static Object* create(STATE) {
    return RespondToToS::create<RespondToToSReturnString>(state);
  }

  static Object* to_s(STATE, Executable* exec, Module* mod, Arguments& args) {
    return String::create(state, "blah");
  }
};

class RespondToToSReturnCTrue : public RespondToToS {
public:
  static Object* create(STATE) {
    return RespondToToS::create<RespondToToSReturnCTrue>(state);
  }

  static Object* to_s(STATE, Executable* exec, Module* mod, Arguments& args) {
    return cTrue;
  }
};

class ConstMissing {
public:
  template <class T>
    static Module* create(STATE) {
      Class* klass = Class::create(state, G(object));

      Symbol* sym = state->symbol("const_missing");
      Executable* const_missing = Executable::allocate(state, cNil);
      const_missing->primitive(state, sym);
      const_missing->set_executor(T::const_missing);

      klass->method_table()->store(state, sym, nil<String>(), const_missing,
          nil<LexicalScope>(), Fixnum::from(0), G(sym_public));

      Module* obj = state->memory()->new_object<Module>(state, klass);

      return obj;
    }
};

class ReturnConst : public ConstMissing {
public:
  static Module* create(STATE) {
    return ConstMissing::create<ReturnConst>(state);
  }

  static Object* const_missing(STATE, Executable* exec, Module* mod, Arguments& args) {
    return Fixnum::from(42);
  }
};

class VMTest {
public:
  Machine* machine;
  State* state;
  ConfigParser* config_parser;
  Configuration config;


  void setup_call_frame(CallFrame* cf, StackVariables* scope, int size) {
    scope->initialize(cNil, nil<Symbol>(), cNil, Module::create(state), 0);

    cf->prepare(size);
    cf->stack_ptr_ = cf->stk - 1;
    cf->previous = nullptr;
    cf->lexical_scope_ = nil<LexicalScope>();
    cf->dispatch_data = nullptr;
    cf->compiled_code = nil<CompiledCode>();
    cf->flags = 0;
    cf->top_scope_ = nullptr;
    cf->scope = scope;
    cf->arguments = nullptr;
    cf->unwind = nullptr;
  }

  // TODO: Fix this
  void initialize_as_root(STATE) {
    state->vm()->set_current_thread();

    state->vm()->managed_phase(state);

    TypeInfo::auto_learn_fields(state);

    state->vm()->bootstrap_ontology(state);

    // Setup the main Thread, which is wrapper of the main native thread
    // when the VM boots.
    Thread::create(state, state->vm());
    state->vm()->thread()->alive(state, cTrue);
    state->vm()->thread()->sleep(state, cFalse);
  }

  void create() {
    machine = new Machine(0, nullptr);

    VM* vm = machine->thread_nexus()->new_vm(machine);
    state = new State(vm);
    initialize_as_root(state);
  }

  void destroy() {
    VM::discard(state, state->vm());
    delete state;

    machine->halt();
    delete machine;
  }

  void setUp() {
    create();
  }

  void tearDown() {
    destroy();
  }
};

#endif
