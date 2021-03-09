defmodule DBAgent do

  use DBConnLegacy


  defmodule Query do
    defstruct [:query]
  end

  @spec start_link((() -> state :: any), Keyword.t) :: GenServer.on_start
  def start_link(fun, opts \\ []) when is_function(fun, 0) do
    opts = [init: fun, pool: DBConnLegacy.Connection, sync_connect: true,
            backoff: nil] ++ opts
    DBConnLegacy.start_link(__MODULE__, opts)
  end

  @spec get(DBConnLegacy.conn, ((state :: any) -> value), timeout) ::
    value when value: var
  def get(conn, fun, timeout \\ 5_000) do
    DBConnLegacy.execute!(conn, %Query{query: :get}, fun,
      [pool_timeout: timeout])
  end

  @spec update(DBConnLegacy.conn, ((state :: any) -> new_state :: any), timeout) ::
    :ok
  def update(conn, fun, timeout \\ 5_000) do
    DBConnLegacy.execute!(conn, %Query{query: :update}, fun,
      [pool_timeout: timeout])
  end

  @spec get(DBConnLegacy.conn, ((state :: any) -> {value, new_state :: any}), timeout) ::
    value when value: var
  def get_and_update(conn, fun, timeout \\ 5_000) do
    DBConnLegacy.execute!(conn, %Query{query: :get_and_update}, fun,
      [pool_timeout: timeout])
  end

  @spec transaction(DBConnLegacy.conn, ((DBConnLegacy.t) -> res),  timeout) ::
    {:ok, res} | {:error, reason :: any} when res: var
  def transaction(conn, fun, timeout \\ 5_000) when is_function(fun, 1) do
    DBConnLegacy.transaction(conn, fun, [pool_timeout: timeout])
  end

  @spec rollback(DBConnLegacy.t, reason :: any) :: no_return
  defdelegate rollback(conn, reason), to: DBConnLegacy

  ## DBConnLegacy API

  def connect(opts) do
    fun = Keyword.fetch!(opts, :init)
    {:ok, %{state: fun.(), status: :idle, rollback: nil}}
  end

  def checkout(s), do: {:ok, s}

  def checkin(s), do: {:ok, s}

  def handle_execute(%Query{query: :get}, fun, _, %{state: state} = s) do
    {:ok, fun.(state), s}
  end
  def handle_execute(%Query{query: :update}, fun, _, %{state: state} = s) do
    {:ok, :ok, %{s | state: fun.(state)}}
  end
  def handle_execute(%Query{query: :get_and_update}, fun, _, s) do
    %{state: state} = s
    {res, state} = fun.(state)
    {:ok, res, %{s | state: state}}
  end

  def handle_close(_, _, s) do
    {:ok, nil, s}
  end

  def handle_begin(_, %{status: :idle, state: state} = s) do
    {:ok, :began, %{s | status: :transaction, rollback: state}}
  end

  def handle_commit(_, %{status: :transaction} = s) do
    {:ok, :committed, %{s | status: :idle, rollback: nil}}
  end

  def handle_rollback(_, %{status: :transaction, rollback: state} = s) do
    {:ok, :rolledback, %{s | state: state, status: :idle, rollback: nil}}
  end
end

defimpl DBConnLegacy.Query, for: DBAgent.Query do

  alias DBAgent.Query

  def parse(%Query{query: tag} = query, _)
  when tag in [:get, :update, :get_and_update] do
    query
  end

  def describe(query, _), do: query

  def encode(_, fun, _) when is_function(fun, 1), do: fun
  def encode(_, other, _) do
    raise ArgumentError, "#{inspect other} is not 1-arity fun"
  end

  def decode(_, result, _), do: result
end
