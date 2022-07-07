<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PartnerGroup extends Model
{
    use HasFactory;

    protected $table = 'partner_group';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'image'
    ];



}
