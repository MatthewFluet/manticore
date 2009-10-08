(* eager-future.pml
 *
 * COPYRIGHT (c) 2009 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Components for building futures with eager semantics.
 *)

structure EagerFuture (* : FUTURE *) =
  struct

    _primcode(

#define IVAR_OFF         0
#define CANCELABLE_OFF   1

      typedef future = [
	  ImplicitThreadIVar.ivar,	(* result *)
	  Option.option			(* cancelable *)
	];

      define @future-no-cancelation (f : fun(unit / exh -> any) / exh : exh) : future =
	let ivar : ImplicitThreadIVar.ivar = ImplicitThreadIVar.@empty-ivar(/ exh)       
	let fut : future = alloc (ivar, Option.NONE)

      (* fiber that represents the context of the future *)
	cont k (x : unit) = return(fut)
	let thd : ImplicitThread.thread = ImplicitThread.@thread(k, Option.NONE / exh)
	do ImplicitThread.@spawn(thd / exh)

	cont exh' (exn : exn) =
	  do ImplicitThreadIVar.@put(ivar, Result.EXN(exn) / exh)
	  SchedulerAction.@stop()

	let v : any = apply f (UNIT / exh')

	let wasNotMigrated : bool = ImplicitThread.@remove-thread(thd / exh)
	case wasNotMigrated
	 of true =>
	    (* fast clone *)
	      let ivar : ImplicitThreadIVar.ivar = ImplicitThreadIVar.@ivar(Result.RES(v) / exh)
	      let fut : future = alloc(ivar, Option.NONE)
	      return(fut)
	  | false =>
	    (* slow clone *)
	      do ImplicitThreadIVar.@put(ivar, Result.RES(v) / exh)
	      SchedulerAction.@stop()
	end
      ;

      define @future-with-cancelation (f : fun(unit / exh -> any) / exh : exh) : future =
	let ivar : ImplicitThreadIVar.ivar = ImplicitThreadIVar.@empty-ivar(/ exh)
	let c : Cancelation.cancelable = Cancelation.@new(/ exh)
	let fut : future = alloc(ivar, Option.SOME(c))

      (* fiber that represents the context of the future *)
	cont k (x : unit) = return(fut)
	let thd : ImplicitThread.thread = ImplicitThread.@thread(k, Option.NONE / exh)
	do ImplicitThread.@spawn(thd / exh)

      (* fiber that runs the body of the future *)
	cont k' (x : unit) = 
	  cont exh' (exn : exn) =
	    do ImplicitThreadIVar.@put(ivar, Result.EXN(exn) / exh)
	    SchedulerAction.@stop()
	  let v : any = apply f (UNIT / exh')

	  let wasNotMigrated : bool = ImplicitThread.@remove-thread(thd / exh)
	case wasNotMigrated
	 of true =>
	    (* fast clone *)
	      let ivar : ImplicitThreadIVar.ivar = ImplicitThreadIVar.@ivar(Result.RES(v) / exh)
	      let fut : future = alloc(ivar, Option.NONE)
	      return(fut)
	  | false =>
	    (* slow clone *)
	      do ImplicitThreadIVar.@put(ivar, Result.RES(v) / exh)
	      SchedulerAction.@stop()
	end

        let thd : ImplicitThread.thread = ImplicitThread.@thread(k', Option.SOME(c) / exh)
        do ImplicitThread.@run-out-of-scheduler(thd / exh)

	let e : exn = Fail(@"EagerFuture.@future-with-cancelation: impossible")
	throw exh(e)
      ;

      define @future (arg : [fun(unit / exh -> any), bool] / exh : exh) : future =
	case SELECT(1, arg)
	 of true => @future-with-cancelation(SELECT(0, arg) / exh)
	 | false => @future-no-cancelation(SELECT(0, arg) / exh)
	end
      ;

      define @touch (fut : future / exh : exh) : any =
	let res : Result.result = ImplicitThreadIVar.@get(SELECT(IVAR_OFF, fut) / exh)
        case res
	 of Result.RES(x : any) => return(x)
	  | Result.EXN(exn : exn) => throw exh(exn)
	end
      ;

      define @poll (fut : future / exh : exh) : Option.option =
	ImplicitThreadIVar.@poll(SELECT(IVAR_OFF, fut) / exh)
      ;

      define @cancel (fut : future / exh : exh) : unit =
        case SELECT(CANCELABLE_OFF, fut)
	 of Option.NONE =>
	    (* QUESTION: is this an error? *)
	    return(UNIT)
	  | Option.SOME(c : Cancelation.cancelable) =>
	    do Cancelation.@cancel(c / exh)
            return(UNIT)
        end
      ;

    )

    type 'a thunk = unit -> 'a
    type 'a future = _prim(future)
    val future : ('a thunk * bool) -> 'a future = _prim(@future)
    val touch : 'a future -> 'a = _prim(@touch)
    val poll : 'a future -> 'a Result.result Option.option = _prim(@poll)
    val cancel : 'a future -> unit = _prim(@cancel)

  end