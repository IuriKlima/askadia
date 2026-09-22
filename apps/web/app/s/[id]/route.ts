import {GET as serve} from '../../api/sites/[...path]/route';
export async function GET(request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;return serve(request,{params:Promise.resolve({path:[id]})});}
