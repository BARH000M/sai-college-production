type MutationGateClient = {
  rpc(name: "sai_assert_mutations_enabled"): PromiseLike<{
    error: { code?: string } | null;
  }>;
};

export async function mutationGateOpen(client: MutationGateClient): Promise<boolean> {
  const { error } = await client.rpc("sai_assert_mutations_enabled");
  if (error) {
    console.error("Mutation gate rejected the operation", error.code ?? "unknown");
    return false;
  }
  return true;
}
