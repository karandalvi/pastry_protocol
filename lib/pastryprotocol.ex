defmodule PastryProtocol do

  def main(input) do
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    IO.puts "Nodes   : #{numNodes}"
    IO.puts "Requests: #{numRequests}"
    nodeList = start(numNodes, [], [])

    # {:ok, host} = :inet.gethostname
    # {:ok, {a,b,c,d}} = :inet.getaddr(host, :inet)
    # a = to_string(a)
    # b = to_string(b)
    # c = to_string(c)
    # d = to_string(d)
    # serverIp = a<>"."<>b<>"."<>c<>"."<>d
    # Node.start :"boss@#{serverIp}"

    # :observer.start


    send self, {:getStatsNew}
    loop(nodeList, numNodes, numRequests, [])
  end

  def start(numNodes, nodeList, pidList) when numNodes > 0 do
    # newNode = :crypto.hash(:md5, Integer.to_string(numNodes)) |> Base.encode16()
    newNode = 100 + numNodes
    newPid = spawn(PNode, :init, [Integer.to_string(newNode), Integer.to_string(newNode)])
    # newPid = spawn(PNode, :init, [newNode, Integer.to_string(numNodes)])
    send newPid, {:console, self}
    if length(pidList) > 0 do
      # send newPid, {:join, Enum.at(pidList, length(pidList)-1)}
      # send newPid, {:join, Enum.at(pidList, round(:math.floor(:rand.uniform() * length(pidList))))}
      :timer.sleep(100)
      send newPid, {:join, Enum.at(pidList, 0)}
    end
    nodeList = nodeList ++ [newNode]
    pidList = pidList ++ [newPid]
    start(numNodes-1, nodeList, pidList)
  end

  def start(numNodes, nodeList, pidList) when numNodes <= 0 do
    [nodeList, pidList]
  end

  def loop(nodeList, numNodes, numRequests, hops) do
    receive do

      {:getStatsNew} ->
        nameList = Enum.at(nodeList, 0)
        pidList = Enum.at(nodeList, 1)
        # :timer.sleep(10000)
        # for x <- pidList do
        #   send x, {:print}
        # end
        # x = 2000
        # r = round(:math.floor(:rand.uniform() * length(pidList)))
        # if (r != 2000) do
        #   IO.puts "Sending Request: Key - #{Enum.at(nameList, r)} to Node - #{Enum.at(nameList, x)}"
        #   send Enum.at(pidList, x), {:sendRequest, Enum.at(pidList, r), Enum.at(nameList, r)}
        # end

        loop(nodeList, numNodes, numRequests, hops)

      {:getStats} ->
        nameList = Enum.at(nodeList, 0)
        pidList = Enum.at(nodeList, 1)
        # :timer.sleep(10000)
        # for x <- Enum.at(nodeList, 1) do
          # send x, {:print}
          # r = round(:math.floor(:rand.uniform() * length(pidList)))
          # if (x != Enum.at(pidList, r)) do
            # send x, {:sendRequest, Enum.at(pidList, r), Enum.at(nameList, r)}
          # end
        # end
        loop(nodeList, numNodes, numRequests, hops)

      {:collectHopNumber, hopCount} ->
        hops = hops ++ [hopCount]
        IO.puts hopCount
        # if length(hops) == (numRequests * numNodes) do
        #   IO.puts "All hops completed"
        # end
        loop(nodeList, numNodes, numRequests, hops)
    end
  end
end
