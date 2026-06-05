# An anonymous block parameter (&) has no name, so a local call is never attributed to it.
def forward(&)
  worker = build_worker
  worker.call
end
