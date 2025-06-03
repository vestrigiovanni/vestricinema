import { useQuery, QueryKey } from '@tanstack/react-query';

export const useApiQuery = <T>(key: QueryKey, fn: () => Promise<T>) => {
  return useQuery({ queryKey: key, queryFn: fn, retry: 2 });
};
