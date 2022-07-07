<div class="modal fade text-left" id="add_edit_modal" tabindex="-1" role="dialog" data-backdrop="static" aria-labelledby="myModalLabel33" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h4 class="modal-title">Add & edit shop</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="" method="POST" id="js_add_edit_from" enctype="multipart/form-data">
                @csrf

                <input type="hidden" name="old_name">
                <div class="modal-body">
                    <div class="needs-validation">
                        <div class="row">
                            <div class="col-md-4">
                                <label>Kategoriyani tanlang</label>
                                <select class="form-control js_partner_id select2" name="partner_id">
                                    @foreach($partners as $p)
                                        <option value="{{ $p->id }}">{{ $p->name }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-md-8">
                                <label>Ichki kategoriyani tanlang</label>
                                <select class="form-control js_parent_id select2" name="parent_id">
                                    <option value="0">---</option>
                                    @foreach($parents as $p)
                                        <option value="{{ $p->id }}">{{ $p->name }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-md-12">
                                <label>Nomi</label>
                                <div class="form-group">
                                    <input type="text" name="name" class="form-control js_name" />
                                    <div class="invalid-feedback">Nomini kiriting!</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <label>Narxi</label>
                                <div class="form-group">
                                    <input type="text" name="price" class="form-control js_price" />
                                    <div class="invalid-feedback">Narxini kiriting!</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <label>Rasm</label>
                                <div class="custom-file">
                                    <input type="file" class="custom-file-input" id="image" name="image">
                                    <label class="custom-file-label" for="image">Rasmni tanlang</label>
                                    <div class="invalid-feedback">Rasmni tanlang!</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <label>Chegirma</label>
                                <div class="form-group">
                                    <input type="text" name="discount" class="form-control js_discount" value="0" />
                                    <div class="invalid-feedback">Nomini kiriting!</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <label>Holati</label>
                                <select class="form-control js_active" name="active">
                                    <option value="1">Active</option>
                                    <option value="0">No active</option>
                                </select>
                            </div>
                            <div class="col-12 mt-1">
                                <div class="form-group">
                                    <label for="comments">Izoh uchun</label>
                                    <textarea class="form-control" id="comments" rows="2" name="comments"></textarea>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer position-relative">
                    <i class="fas fa-check check-success-icon d-none js_check_icon"></i>
                    <input type="submit" class="btn btn-outline-success btn-sm js_form_save_btn" value="Saqlash" />
                    <input type="submit" class="btn btn-outline-primary btn-sm js_form_save_close_btn" value="Saqlash va chiqish" />
                    <button type="button" class="btn btn-outline-secondary btn-sm js_form_close_btn" data-dismiss="modal">Bekor qilish</button>
                </div>
            </form>
        </div>
    </div>
</div>
