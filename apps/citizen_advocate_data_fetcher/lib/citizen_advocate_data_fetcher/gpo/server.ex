defmodule CitizenAdvocateDataFetcher.GPO.Server do
  use GenServer

  @timeout Application.get_env(:citizen_advocate_data_fetcher, :timeouts)[:gpo]
  @bill_types Application.get_env(:citizen_advocate_data_fetcher, :gpo)[:bill_types]
  @congress Application.get_env(:citizen_advocate_data_fetcher, :congress)

  ## Client API
  
  def fetch_gpo_bill_data do
    GenServer.call(__MODULE__, {:fetch_bills_data}, @timeout)
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  ## Server API

  def init(nil) do

    # TODO: currently, if the pools die, they are never restarted..
    send(self(), {:start_fetcher_pool})
    send(self(), {:start_parser_pool})

    {:ok, %{}}
  end

  def handle_call({:fetch_bills_data}, _from, state) do
    tasks = Enum.map(@bill_types, &queue_fetch(&1))

    results = tasks
      |> Enum.map(fn(task) ->
        {:ok, path} = Task.await(task, @timeout)
        results = list_files(path)
          |> Enum.map(&queue_parse(&1))
          |> Enum.map(fn(task) -> Task.await(task, @timeout) end)
        File.rm_rf(path)
        results
      end)
      |> List.flatten() # above creates list of result lists, so flatten it...
      |> Enum.map(fn(response) -> response end)

    {:reply, results, state}
  end

  def handle_info({:start_fetcher_pool}, state) do
    CitizenAdvocateDataFetcher.GPO.Supervisor.start_fetcher_pool
    {:noreply, state}
  end

  def handle_info({:start_parser_pool}, state) do
    CitizenAdvocateDataFetcher.GPO.Supervisor.start_parser_pool
    {:noreply, state}
  end

  ## Internal Helpers

  defp queue_fetch(bill_type) do
    Task.async(
      fn -> :poolboy.transaction(:gpo_fetchers,
        &(GenServer.call(&1, {:fetch_bills, { :congress, @congress, :bill_type, bill_type }}, @timeout)
      ), @timeout)
    end)
  end

  defp queue_parse(filepath) do
    Task.async(
      fn -> :poolboy.transaction(:gpo_parsers,
        &(GenServer.call(&1, {:parse_bill, { :filepath, filepath }}, @timeout)
      ), @timeout)
    end)
  end

  defp list_files(path) do
    {:ok, filenames} = File.ls(path)
    filenames
      |> Enum.map(fn(filename) -> Path.join([path, filename]) end)
  end
end
