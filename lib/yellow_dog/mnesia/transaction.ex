defmodule YellowDog.Mnesia.Transaction do
  require YellowDog.Mnesia.Mnesia
  require YellowDog.Mnesia.Error
  require YellowDog.Mnesia.TransactionAborted

  @moduledoc """
  YellowDog.Mnesia's wrapper around Mnesia transactions. This module exports
  methods `execute/2` and `execute_sync/2`, and their bang versions,
  which accept a function to be executed and an optional argument to
  set the maximum no. of retries until the transaction succeeds.

  `execute/1` and `execute!/1` can be directly called from the base
  `YellowDog.Mnesia` module as the alias `YellowDog.Mnesia.transaction/1` and
  `YellowDog.Mnesia.transaction!/1` methods, but if you want to specify a
  custom `retries` value or use the synchronous version, you should
  use the methods in this module.


  ## Examples

  ```
  # Read a User record
  {:ok, user} =
    YellowDog.Mnesia.transaction fn ->
      YellowDog.Mnesia.Query.read(User, id)
    end

  # Get all Users, raising errors on aborts
  users =
    YellowDog.Mnesia.transaction! fn ->
      YellowDog.Mnesia.Query.all(User)
    end

  # Update a User record on all nodes synchronously,
  # with a maximum of 5 retries
  operation = fn ->
    YellowDog.Mnesia.Query.write(%User{id: 3, name: "New Value"})
  end
  YellowDog.Mnesia.Transaction.execute_sync(operation, 5)
  ```
  """

  # Type Definitions
  # ----------------

  @typedoc "Maximum no. of retries for a transaction"
  @type retries :: :infinity | non_neg_integer

  # Public API
  # ----------

  @doc """
  Execute passed function as part of an Mnesia transaction.

  Default value of `retries` is `:infinity`. Returns either
  `{:ok, result}` or `{:error, reason}`. Also see
  `:mnesia.transaction/2`.
  """
  @spec execute(fun, retries) :: {:ok, any} | {:error, any}
  def execute(function, retries \\ :infinity) do
    :transaction
    |> YellowDog.Mnesia.Mnesia.call_and_catch([function, retries])
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Same as `execute/2` but returns the result or raises an error.
  """
  @spec execute!(fun, retries) :: any | no_return
  def execute!(fun, retries \\ :infinity) do
    fun
    |> execute(retries)
    |> handle_result
  end

  @doc """
  Execute the transaction in synchronization with all nodes.

  This method waits until the data has been committed and logged to
  disk (if used) on all involved nodes before it finishes. This is
  useful to ensure that a transaction process does not overload the
  databases on other nodes.

  Returns either `{:ok, result}` or `{:error, reason}`. Also see
  `:mnesia.sync_transaction/2`.
  """
  @spec execute_sync(fun, retries) :: {:ok, any} | {:error, any}
  def execute_sync(function, retries \\ :infinity) do
    :sync_transaction
    |> YellowDog.Mnesia.Mnesia.call_and_catch([function, retries])
    |> YellowDog.Mnesia.Mnesia.handle_result()
  end

  @doc """
  Same as `execute_sync/2` but returns the result or raises an error.
  """
  @spec execute_sync!(fun, retries) :: any | no_return
  def execute_sync!(fun, retries \\ :infinity) do
    fun
    |> execute_sync(retries)
    |> handle_result
  end

  @doc """
  Checks if you are inside a transaction.
  """
  @spec inside?() :: boolean
  def inside? do
    YellowDog.Mnesia.Mnesia.call(:is_transaction)
  end

  @doc """
  Aborts a YellowDog.Mnesia transaction.

  Causes the transaction to return an error tuple with the passed
  argument: `{:error, {:transaction_aborted, reason}}`. Outside
  the context of a transaction, simply raises an error.

  In the bang versions of the transactions, it raises a
  `YellowDog.Mnesia.TransactionAborted` error instead of returning the
  error tuple. Default value for reason is `:no_reason_given`.
  """
  @spec abort(term) :: no_return
  def abort(reason \\ :no_reason_given) do
    case inside?() do
      true ->
        :mnesia.abort({:transaction_aborted, reason})

      false ->
        YellowDog.Mnesia.Error.raise_from_code(:no_transaction)
    end
  end

  # Private Helpers
  # ---------------

  # Handle Transaction Results. The 'result' should already
  # be 'handled' by the `YellowDog.Mnesia.Mnesia` module before this
  # is called.
  defp handle_result(result) do
    case result do
      {:ok, term} ->
        term

      {:error, {:transaction_aborted, reason}} ->
        YellowDog.Mnesia.TransactionAborted.raise(reason)

      {:error, reason} ->
        YellowDog.Mnesia.Error.raise("Transaction Failed with: #{inspect(reason)}")

      term ->
        term
    end
  end
end
