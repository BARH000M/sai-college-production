import { beforeEach, expect, test, vi } from 'vitest';
import { collegeRouter } from './collegeRouter';
import type { TrpcContext } from './context';
const mocks=vi.hoisted(()=>({getDb:vi.fn()}));
vi.mock('./queries/connection',()=>({getDb:mocks.getDb}));
const input={studentName:'Test Student',phone:'771234567',programSlug:'hsk-1'};
function caller(user:unknown={id:7}){return collegeRouter.createCaller({user} as unknown as TrpcContext)}
beforeEach(()=>vi.resetAllMocks());
test('unauthenticated admission writes are rejected before database access',async()=>{await expect(caller(null).createRequest(input)).rejects.toMatchObject({code:'UNAUTHORIZED'});expect(mocks.getDb).not.toHaveBeenCalled()});
test('unknown program is rejected without insertion',async()=>{const insert=vi.fn();mocks.getDb.mockReturnValue({select:()=>({from:()=>({where:()=>({limit:async()=>[]})})}),insert});await expect(caller().createRequest(input)).rejects.toMatchObject({code:'BAD_REQUEST'});expect(insert).not.toHaveBeenCalled()});
test('valid request reference fits the existing 24 character database column',async()=>{const created={id:4,reference:'sample'};const values=vi.fn(()=>({$returningId:async()=>[{id:4}]}));const select=vi.fn().mockReturnValueOnce({from:()=>({where:()=>({limit:async()=>[{id:1}]})})}).mockReturnValueOnce({from:()=>({where:async()=>[created]})});mocks.getDb.mockReturnValue({select,insert:()=>({values})});await expect(caller().createRequest(input)).resolves.toEqual(created);const saved=values.mock.calls[0] as unknown as [{reference:string,userId:number}];expect(saved[0].reference).toMatch(/^SAI-[A-F0-9]{20}$/);expect(saved[0].reference.length).toBe(24);expect(saved[0].userId).toBe(7)});
