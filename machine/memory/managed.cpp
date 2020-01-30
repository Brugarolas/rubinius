#include "vm.hpp"
#include "state.hpp"
#include "machine.hpp"

#include "util/thread.hpp"
#include "memory/managed.hpp"

#include "diagnostics/machine.hpp"
#include "diagnostics/memory.hpp"

#include <thread>
#include <sstream>

namespace rubinius {
namespace memory {
  utilities::thread::ThreadData<ManagedThread*> _current_thread;

  ManagedThread::ManagedThread(uint32_t id, Machine* m,
      ManagedThread::Kind kind, const char* name)
    : kind_(kind)
    , metrics_(new diagnostics::MachineMetrics())
    , os_thread_(0)
    , id_(id)
  {
    if(name) {
      name_ = std::string(name);
    } else {
      std::ostringstream thread_name;
      thread_name << "ruby." << id_;
      name_ = thread_name.str();
    }
  }

  ManagedThread::~ManagedThread() {
    /* TODO: diagnostics, metrics
    if(metrics::Metrics* metrics = shared_.metrics()) {
      metrics->add_historical_metrics(metrics_);
    }
    */
  }

  void ManagedThread::set_name(STATE, const char* name) {
    if(pthread_self() == os_thread_) {
      utilities::thread::Thread::set_os_name(name);
    }
    name_.assign(name);
  }

  ManagedThread* ManagedThread::current() {
    return _current_thread.get();
  }

  void ManagedThread::set_current_thread(ManagedThread* th) {
    utilities::thread::Thread::set_os_name(th->name().c_str());
    th->os_thread_ = pthread_self();
    _current_thread.set(th);
  }
}
}
